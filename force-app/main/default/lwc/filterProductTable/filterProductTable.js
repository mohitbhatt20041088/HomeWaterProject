import { LightningElement, api } from 'lwc';

const columns = [
    { 
        label: 'Product Name', 
        fieldName: 'Name',
        type: 'text',
        initialWidth: 250,
        wrapText: true
    },
    { 
        label: 'Product Code', fieldName: 'ProductCode', type: 'text', initialWidth: 150
    },
    { 
        label: 'Family', fieldName: 'Family', type: 'text', initialWidth: 140
    },
    { 
        label: 'Billing Type', fieldName: 'Billing_Type__c', type: 'text', initialWidth: 140
    },
    { 
        label: 'Stage', fieldName: 'Stage__c', type: 'text', initialWidth: 120
    },
    { 
        label: 'Preferred Block', fieldName: 'Preferred_Block__c', type: 'text', initialWidth: 150
    }
];

export default class FilterProductTable extends LightningElement {
    // Note: @track is no longer needed for objects or arrays
    columns = columns;
    isLoading = false;
    data = [];
    selectedRows = [];

    @api
    set filteredProducts(value) {
        if (value && Array.isArray(value)) {
            // Assign the data directly
            this.data = value;
        } else {
            this.data = [];
        }
        // Always clear selections when new filtered data arrives for better UX
        // This prevents products from being pre-selected when applying new filters
        this.selectedRows = [];
    }

    get filteredProducts() {
        return this.data;
    }

    get hasData() {
        return this.data && this.data.length > 0;
    }

    get recordCount() {
        return this.data ? this.data.length : 0;
    }

    handleRowSelection(event) {
        const selectedRecords = event.detail.selectedRows;
        // **FIXED**: Map the records to get an array of just the IDs
        this.selectedRows = selectedRecords.map(record => record.Id);
        
        // Dispatch the full selected records for other components to use
        const selectionEvent = new CustomEvent('productselection', {
            detail: { selectedProducts: selectedRecords }
        });
        this.dispatchEvent(selectionEvent);
    }

    @api
    getSelectedProducts() {
        // Find the full records that correspond to the selected IDs
        const selectedIds = new Set(this.selectedRows);
        return this.data.filter(record => selectedIds.has(record.Id));
    }    
}