import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { LightningElement, wire, track, api } from 'lwc';
import PRODUCT2_OBJECT from "@salesforce/schema/Product2";
import ORDERLINE_OBECJT from "@salesforce/schema/OrderItem";
import BILLING_TYPE_FIELD from "@salesforce/schema/Product2.Billing_Type__c";
import Installation_Type_FIELD from "@salesforce/schema/Product2.Installation_Type__c";
import Family_FIELD from "@salesforce/schema/Product2.Family";
import Stage__FIELD from "@salesforce/schema/Product2.Stage__c";
import Preferred_Block__FIELD from "@salesforce/schema/Product2.Preferred_Block__c";
import Product_Terms__FIELD from "@salesforce/schema/OrderItem.Product_Terms__c";
import { NavigationMixin } from 'lightning/navigation';
import getFilterProducts from '@salesforce/apex/FilterProductsHelper.getFilterProducts';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class FilterCriteriaComponent extends NavigationMixin (LightningElement) {
    
    // Accept zipCode from parent
    @api zipCode;
    
    // Current view management
    @track currentView = 'filter'; // 'filter', 'table', 'detail', 'user-detail'
    @track filteredProductsData = [];
    @track selectedProductsData = [];
    
    billingPicklistOptions;
    installationPicklistOptions;
    familyPicklistOptions;
    stagePicklistOptions;
    preferredBlockPicklistOptions;
    productTermPicklistOptions;
    billVal = '';
    installationVal = '';
    familyVal = '';
    stageVal = '';
    perferredBlockVal = '';
    productTermVal = '';
    
    // Component initialization - only handle refresh detection
    connectedCallback() {
        // Check if this is a fresh session/refresh
        if (this.isFreshSession()) {
            this.clearAllStoredData();
            this.markSessionActive();
        }
    }

    clearAllStoredData() {
        localStorage.removeItem('filterCriteriaValues');
        localStorage.removeItem('filteredProductsData');
        localStorage.removeItem('selectedProductIds');
        localStorage.removeItem('productDetailFormData');
        localStorage.removeItem('productDetailData');
        localStorage.removeItem('navigationState');
        localStorage.removeItem('selectedProductsData');
    }

    markSessionActive() {
        sessionStorage.setItem('sessionActive', 'true');
    }

    isFreshSession() {
        return !sessionStorage.getItem('sessionActive');
    }
    
    // Save current navigation state
    saveNavigationState() {
        const navigationState = {
            currentView: this.currentView,
            filteredProductsData: this.filteredProductsData,
            filterCriteria: {
                billVal: this.billVal,
                installationVal: this.installationVal,
                familyVal: this.familyVal,
                stageVal: this.stageVal,
                perferredBlockVal: this.perferredBlockVal,
                productTermVal: this.productTermVal
            }
        };
        localStorage.setItem('navigationState', JSON.stringify(navigationState));
    }
    
    // Load saved navigation state
    loadNavigationState() {
        try {
            const savedState = localStorage.getItem('navigationState');
            if (savedState) {
                const state = JSON.parse(savedState);
                this.filteredProductsData = state.filteredProductsData || [];
                // Restore filter criteria
                if (state.filterCriteria) {
                    this.billVal = state.filterCriteria.billVal || '';
                    this.installationVal = state.filterCriteria.installationVal || '';
                    this.familyVal = state.filterCriteria.familyVal || '';
                    this.stageVal = state.filterCriteria.stageVal || '';
                    this.perferredBlockVal = state.filterCriteria.perferredBlockVal || '';
                    this.productTermVal = state.filterCriteria.productTermVal || '';
                }
            }
        } catch (error) {
            console.error('Error loading navigation state:', error);
        }
    }
    
    // Save selected products data
    saveSelectedProducts(data) {
        localStorage.setItem('selectedProductsData', JSON.stringify(data));
    }
    
    // Load selected products data
    loadSelectedProducts() {
        try {
            const savedProducts = localStorage.getItem('selectedProductsData');
            if (savedProducts) {
                this.selectedProductsData = JSON.parse(savedProducts);
            }
        } catch (error) {
            console.error('Error loading selected products:', error);
        }
    }
    
    // Force table component to reload selections
    forceTableSelectionReload() {
        // Use setTimeout to ensure the table component is rendered before calling the method
        setTimeout(() => {
            const tableComponent = this.template.querySelector('c-filter-product-table-component');
            if (tableComponent && tableComponent.reloadSelections) {
                tableComponent.reloadSelections();
            }
        }, 100);
    }
    
    
    
    
    @wire(getObjectInfo,{objectApiName: PRODUCT2_OBJECT})
    productObjectInfo

    @wire(getObjectInfo,{objectApiName: ORDERLINE_OBECJT})
    OrderItemObjectInfo



    // ------------- billing type -------------
@wire(getPicklistValues, {
    recordTypeId: "$productObjectInfo.data.defaultRecordTypeId",
    fieldApiName: BILLING_TYPE_FIELD
})
wiredBillingPickList({ data, error }) {
    if (data) {
        this.billingPicklistOptions = data.values.map(v => ({
            label: v.label,
            value: v.value
        }));
    } else if (error) {
        console.error('billing picklist error', error);
    }
}

// ------------- installation type -------------
@wire(getPicklistValues, {
    recordTypeId: "$productObjectInfo.data.defaultRecordTypeId",
    fieldApiName: Installation_Type_FIELD
})
wiredInstallationPickList({ data, error }) {
    if (data) {
        this.installationPicklistOptions = data.values.map(v => ({
            label: v.label,
            value: v.value
        }));
    } else if (error) {
        console.error('installation picklist error', error);
    }
}

// ------------- family -------------
@wire(getPicklistValues, {
    recordTypeId: "$productObjectInfo.data.defaultRecordTypeId",
    fieldApiName: Family_FIELD
})
wiredFamilyPickList({ data, error }) {
    if (data) {
        this.familyPicklistOptions = data.values.map(v => ({
            label: v.label,
            value: v.value
        }));
    } else if (error) {
        console.error('family picklist error', error);
    }
}

// ------------- stage -------------
@wire(getPicklistValues, {
    recordTypeId: "$productObjectInfo.data.defaultRecordTypeId",
    fieldApiName: Stage__FIELD
})
wiredStagePickList({ data, error }) {
    if (data) {
        this.stagePicklistOptions = data.values.map(v => ({
            label: v.label,
            value: v.value
        }));
    } else if (error) {
        console.error('stage picklist error', error);
    }
}

// ------------- preferred block -------------
@wire(getPicklistValues, {
    recordTypeId: "$productObjectInfo.data.defaultRecordTypeId",
    fieldApiName: Preferred_Block__FIELD
})
wiredPreferredBlockPickList({ data, error }) {
    if (data) {
        this.preferredBlockPicklistOptions = data.values.map(v => ({
            label: v.label,
            value: v.value
        }));
    } else if (error) {
        console.error('preferred block picklist error', error);
    }
}

// ------------- product terms -------------
@wire(getPicklistValues, {
    recordTypeId: "012000000000000AAA",
    fieldApiName: Product_Terms__FIELD
})
wiredProductTermPickList({ data, error }) {
    if (data) {
        this.productTermPicklistOptions = data.values.map(v => ({
            label: v.label,
            value: v.value
        }));
    } else if (error) {
        console.error('product term picklist error', error);
    }
}


getBillingType(event){
    this.billVal = event.detail.value;
    console.log(this.billVal);
}
getInstallationType(event){
    this.installationVal = event.detail.value;
    console.log(this.installationVal);
}
getStageType(event){
    this.stageVal = event.detail.value;
    console.log(this.stageVal);
}
getFamilyType(event){
    this.familyVal = event.detail.value;
    console.log(this.familyVal);
}
getPreferredBlockType(event){
    this.perferredBlockVal = event.detail.value;
    console.log(this.perferredBlockVal);
}
getProductTermType(event){
    this.productTermVal = event.detail.value;
    console.log(this.productTermVal);
}


    


    handleBackToZip() {
        // Dispatch custom event to notify parent zipCodeComponent
        const backEvent = new CustomEvent('back');
        this.dispatchEvent(backEvent);
    }

    secondScreenHandler() {
        // Product Terms is always required
        if(!this.productTermVal || this.productTermVal.trim() === ''){
            this.showToast('Validation Error ','Please select Product Terms to continue','error');
            return;
        }

        // Check if any filters are selected
        const hasFilters = this.billVal || this.familyVal || this.stageVal || this.perferredBlockVal;
        
        // If no filters are applied, clear all cached filter data to ensure fresh results
        if(!hasFilters) {
            console.log('No filters applied - clearing cached data to show all products');
            this.clearAllStoredData();
        }

            getFilterProducts({
            billingType: this.billVal,
            familyType: this.familyVal,
            stageType: this.stageVal,
            preferredBlockType: this.perferredBlockVal
            })
            .then(result=>{
                console.log('Filter results received:', result.length, 'products');
                this.filteredProductsData = result;
                // Clear any existing selections when new filter is applied
                localStorage.removeItem('selectedProductIds');
                localStorage.removeItem('selectedProductsData');
                this.currentView = 'table';
            })
            .catch(error=>{
            console.error('Error fetching products: ',error);
            })
        
    }


    // Handle navigation from child components
    handleNavigation(event) {
        const { view, data, preserveSelections } = event.detail;
        
        // Save current state before navigation
        this.saveNavigationState();
        
        // Set new view
        this.currentView = view;
        
        // Handle data updates based on navigation
        if (view === 'detail' && data) {
            this.selectedProductsData = data;
            // Save selected products to localStorage for persistence
            this.saveSelectedProducts(data);
        }
        
        // Handle updated product data with quantities and prices for user-detail view
        if (view === 'user-detail' && data) {
            this.selectedProductsData = data; // Update with quantity and price data
            // Save enhanced product data with quantities and prices
            this.saveSelectedProducts(data);
        }
        
        // When navigating back to table, restore filtered products
        if (view === 'table') {
            this.loadNavigationState();
            
            // If preserveSelections flag is set, ensure selections are maintained
            if (preserveSelections) {
                // Force the table component to reload selections from localStorage
                this.forceTableSelectionReload();
            }
        }
        
        // When navigating back to detail, restore selected products
        if (view === 'detail' && !data) {
            this.loadSelectedProducts();
            // Force component refresh by updating selectedProductsData
            this.selectedProductsData = [...this.selectedProductsData];
        }
    }

    // Computed properties for conditional rendering
    get showFilterScreen() {
        return this.currentView === 'filter';
    }

    get showTableScreen() {
        return this.currentView === 'table';
    }

    get showDetailScreen() {
        return this.currentView === 'detail';
    }

    get showUserDetailScreen() {
        return this.currentView === 'user-detail';
    }

    showToast(title,message,variant){
        const event = new ShowToastEvent({
            title:title,
            message:message,
            variant:variant
        });
        this.dispatchEvent(event);
    }

}
