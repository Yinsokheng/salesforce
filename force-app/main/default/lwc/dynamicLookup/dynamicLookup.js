import { LightningElement, api, track } from 'lwc';
import lookupRecords from '@salesforce/apex/DynamicLookupController.lookupRecords';
import searchBySOQL from '@salesforce/apex/DynamicLookupController.searchBySOQL';
import searchBySOSL from '@salesforce/apex/DynamicLookupController.searchBySOSL';

export default class DynamicLookup extends LightningElement {
    @api objectApiName = 'Account';
    @api label = 'Relate To';
    @api searchField = 'Name';
    @api secondaryField = 'BillingCity';
    @api icon = 'standard:account';
    @api filter = 'Id != null';
    @api techniqueQuery = 'SOQL'; // 'SOQL' or 'SOSL'
    @track results = [];
    @track selectedRecord;
    searchText = '';
    dropdownOpen = false;

    get hasSelection() {
        return this.selectedRecord != null;
    }

    get computedDropdownClass() {
        // Build class list without newlines to avoid invalid DOMTokenList tokens
        const classes = [
            'slds-combobox',
            'slds-dropdown-trigger',
            'slds-dropdown-trigger_click',
            this.dropdownOpen ? 'slds-is-open' : ''
        ];
        return classes.filter(Boolean).join(' ');
    }

    handleSearch(event) {
        this.searchText = event.target.value;

        // Choose which Apex method to call based on techniqueQuery
        const apexMethod = this.techniqueQuery === 'SOSL' ? searchBySOSL : searchBySOQL;

        apexMethod({
            objectApiName: this.objectApiName,
            searchText: this.searchText,
            searchField: this.searchField,
            secondaryField: this.secondaryField,
            iconName: this.icon,
            filter: this.filter
        }).then(data => {
            this.results = data;
        }).catch(error => {
            console.error('Search failed:', error);
            this.results = [];
        });
    }

    openDropdown() {
        this.dropdownOpen = true;
    }

    selectItem(event) {
        const selectedId = event.currentTarget.dataset.id;
        this.selectedRecord = this.results.find(r => r.id === selectedId);
        this.dropdownOpen = false;

        this.dispatchEvent(
            new CustomEvent('select', { detail: this.selectedRecord })
        );
    }

    clearSelection() {
        this.selectedRecord = null;
        this.searchText = '';
    }
}
