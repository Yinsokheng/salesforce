public with sharing class InterfaceTreeController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getRootIntegrations() {
        List<Integration__c> integrations = [
            SELECT Id, Name FROM Integration__c ORDER BY Name
        ];
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (Integration__c integ : integrations) {
            results.add(new Map<String, Object>{
                'id' => integ.Id,
                'name' => integ.Name,
                'type' => 'integration',
                'hasChildren' => true
            });
        }
        return results;
    }

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getInterfaces(Id integrationId) {
        List<Interfaces__c> interfaces = [
            SELECT Id, Name FROM Interfaces__c WHERE Integration__c = :integrationId ORDER BY Name
        ];
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (Interfaces__c iface : interfaces) {
            results.add(new Map<String, Object>{
                'id' => iface.Id,
                'name' => iface.Name,
                'type' => 'interface',
                'hasChildren' => true
            });
        }
        return results;
    }

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getMessages(Id interfaceId) {
        List<IMessage__c> msgs = [
            SELECT Id, Name FROM IMessage__c WHERE Interface__c = :interfaceId ORDER BY CreatedDate DESC LIMIT 20
        ];
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (IMessage__c msg : msgs) {
            results.add(new Map<String, Object>{
                'id' => msg.Id,
                'name' => msg.Name,
                'type' => 'message',
                'hasChildren' => false
            });
        }
        return results;
    }
}