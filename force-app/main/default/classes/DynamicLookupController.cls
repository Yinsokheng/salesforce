public with sharing class DynamicLookupController {
    @AuraEnabled(cacheable=true)
    public static List<sObject> searchRecords(String objectApiName, String searchKey, String searchField, String filter) {
        if(!Schema.getGlobalDescribe().containsKey(objectApiName)) {
            return new List<sObject>();
        }

        String soql = 'SELECT Id, ' + searchField + ' FROM ' + objectApiName +
                      ' WHERE ' + searchField + ' LIKE \'%' + String.escapeSingleQuotes(searchKey) + '%\'';

        if(String.isNotBlank(filter)) {
            soql += ' AND ' + filter;
        }

        soql += ' LIMIT 10';
    return System.Database.query(soql);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> lookupRecords(
        String objectApiName,
        String searchText,
        String searchField,
        String secondaryField,
        String iconName,
        String filter
    ) {
        // Dispatcher: use SOSL for full-text when no filter and length >= 3, otherwise SOQL
        if (searchText == null) searchText = '';
        String technique = String.isBlank(filter) && searchText.length() >= 3 ? 'SOSL' : 'SOQL';

        if (technique.equals('SOSL')) {
            return searchBySOSL(objectApiName, searchText, searchField, secondaryField, iconName, filter);
        } else {
            return searchBySOQL(objectApiName, searchText, searchField, secondaryField, iconName, filter);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchBySOQL(
        String objectApiName,
        String searchText,
        String searchField,
        String secondaryField,
        String iconName,
        String filter
    ) {
        // Validate object and fields
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(objectApiName)) {
            return new List<Map<String, String>>();
        }
        Schema.DescribeSObjectResult objDesc = gd.get(objectApiName).getDescribe();
        Map<String, Schema.SObjectField> fieldsMap = objDesc.fields.getMap();

        if (!fieldsMap.containsKey(searchField)) {
            return new List<Map<String, String>>();
        }
        Boolean hasSecondary = String.isNotBlank(secondaryField) && fieldsMap.containsKey(secondaryField);

        // Sanitize search text
        String sanitized = searchText == null ? '' : searchText.replaceAll('"|\\\\|\r|\n', ' ').trim();
        String escaped = String.escapeSingleQuotes(sanitized);

        // Build SOQL: search primary and optional secondary fields using LIKE
        String selectClause = 'SELECT Id, ' + searchField + (hasSecondary ? ', ' + secondaryField : '') + ' FROM ' + objectApiName;
        String whereClause = '';

        if (!String.isBlank(escaped)) {
            whereClause = ' WHERE (' + searchField + ' LIKE \'%' + escaped + '%\'';
            if (hasSecondary) {
                whereClause += ' OR ' + secondaryField + ' LIKE \'%' + escaped + '%\'';
            }
            whereClause += ')';
        }

        // Validate and apply filter safely
        if (String.isNotBlank(filter)) {
            Set<String> allowed = new Set<String>(fieldsMap.keySet());
            List<String> tokens = new List<String>();
            for (String t : filter.split('[^A-Za-z0-9_]+')) {
                if (String.isNotBlank(t)) tokens.add(t);
            }
            Boolean ok = true;
            for (String t : tokens) {
                String upper = t.toUpperCase();
                if (upper == 'AND' || upper == 'OR' || upper == 'NOT' || upper == 'NULL' || upper == 'LIKE' || upper == 'IN' || upper == 'IS') continue;
                if (Pattern.matches('^[0-9]+$', t) || (t.startsWith('\'') && t.endsWith('\''))) continue;
                if (!allowed.contains(t)) { ok = false; break; }
            }
            if (ok) {
                whereClause += (String.isBlank(whereClause) ? ' WHERE (' + filter + ')' : ' AND (' + filter + ')');
            } else {
                System.debug('DynamicLookupController.searchBySOQL: rejected unsafe filter: ' + filter);
            }
        }

        String soql = selectClause + whereClause + ' LIMIT 10';
        System.debug('SOQL Query: ' + soql);
        List<SObject> queried = System.Database.query(soql);

        // Format results
        List<Map<String, String>> finalList = new List<Map<String, String>>();
        for (SObject sobj : queried) {
            Map<String, String> row = new Map<String, String>();
            row.put('id', (String)sobj.get('Id'));
            row.put('title', (String)sobj.get(searchField));
            row.put('subtitle', hasSecondary ? (String)sobj.get(secondaryField) : '');
            row.put('icon', iconName);
            finalList.add(row);
        }
        return finalList;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchBySOSL(
        String objectApiName,
        String searchText,
        String searchField,
        String secondaryField,
        String iconName,
        String filter
    ) {
        // Validate object and fields
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(objectApiName)) {
            return new List<Map<String, String>>();
        }
        Schema.DescribeSObjectResult objDesc = gd.get(objectApiName).getDescribe();
        Map<String, Schema.SObjectField> fieldsMap = objDesc.fields.getMap();

        if (!fieldsMap.containsKey(searchField)) {
            return new List<Map<String, String>>();
        }
        Boolean hasSecondary = String.isNotBlank(secondaryField) && fieldsMap.containsKey(secondaryField);

        // Sanitize search text for SOSL
        String sanitized = searchText == null ? '' : searchText.replaceAll('"|\\\\|\r|\n', ' ').trim();
        String soslSearchText = '*' + sanitized + '*';

        // Build and execute SOSL query
        String sq = '\'';
        String sosl = 'FIND ' + sq + String.escapeSingleQuotes(soslSearchText) + sq + ' IN ALL FIELDS RETURNING ' +
                      objectApiName + '(Id, ' + searchField + (hasSecondary ? ', ' + secondaryField : '') + ' LIMIT 10)';

        if (String.isNotBlank(filter)) {
            sosl += ' WHERE ' + filter;
        }

        sosl += ')';
        System.debug('SOSL Query: ' + sosl);

        List<List<SObject>> soslResults = System.Search.query(sosl);
        List<SObject> rows = new List<SObject>();
        if (!soslResults.isEmpty()) {
            rows = soslResults[0];
        }

        // Format results
        List<Map<String, String>> finalList = new List<Map<String, String>>();
        for (SObject sobj : rows) {
            Map<String, String> row = new Map<String, String>();
            row.put('id', (String)sobj.get('Id'));
            row.put('title', (String)sobj.get(searchField));
            row.put('subtitle', hasSecondary ? (String)sobj.get(secondaryField) : '');
            row.put('icon', iconName);
            finalList.add(row);
        }
        return finalList;
    }
}
