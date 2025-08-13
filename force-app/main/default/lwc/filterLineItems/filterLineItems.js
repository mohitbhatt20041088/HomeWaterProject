import { LightningElement, track, wire, api } from 'lwc';
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import Product2_OBJECT from "@salesforce/schema/Product2";
import BILLING_TYPE_FIELD from "@salesforce/schema/Product2.Billing_Type__c";
import INSTALLATION_TYPE_FIELD from "@salesforce/schema/Product2.Installation_Type__c";
import Family_TYPE_FIELD from "@salesforce/schema/Product2.Family";
import STAGE_TYPE_FIELD from "@salesforce/schema/Product2.Stage__c";
import PREFERRED_BLOCK_FIELD from "@salesforce/schema/Product2.Preferred_Block__c";
import QUOTE_LINE_OBJECT from "@salesforce/schema/QuoteLineItem";
import PRODUCT_TERM_FIELD from "@salesforce/schema/QuoteLineItem.Product_Terms__c";
import getFilteredProducts from '@salesforce/apex/FilterProductHandler.getFilteredProducts';
import addProductsToQuote from '@salesforce/apex/FilterProductHandler.addProductsToQuote';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';




export default class FilterLineItems extends LightningElement {
    @api quoteId; // Pass this from parent component
    @api recordId; // Alternative way to get quoteId if component is on Quote record page
    
    headerText = 'Product Filter';
    billingOptions = [];
    installationOptions = [];
    familyOptions = [];
    stageOptions = [];
    preferredBlockOptions = [];
    @track productTermOptions = [];
    
    @track selectedBillingType = '';
    @track selectedInstallationType = '';
    @track selectedFamily = '';
    @track selectedStage = '';
    @track selectedPreferredBlock = '';
    @track selectedProductTerm = '';
    @track isLoading = false;
    @track isAddingProducts = false;

    
    @wire(getObjectInfo, { objectApiName: Product2_OBJECT })
    productObjectInfo;

    @wire(getObjectInfo, { objectApiName: QUOTE_LINE_OBJECT })
    wiredQuoteLineObjectInfo;

    @wire(getPicklistValues, { recordTypeId: "$productObjectInfo.data.defaultRecordTypeId", fieldApiName: BILLING_TYPE_FIELD })
    billingPickList({data, error}){
        if(data){
            this.billingOptions = data.values.map(item => ({ label: item.label, value: item.value }));
        }else if(error){
            this.billingOptions = [];
        }
    }

    @wire(getPicklistValues, { recordTypeId: "$productObjectInfo.data.defaultRecordTypeId", fieldApiName: INSTALLATION_TYPE_FIELD })
    installationPicklist({data, error}){
        if(data){
            this.installationOptions = data.values.map(item => ({label: item.label, value: item.value}));
        }else if(error){
            this.installationOptions = [];
        }
    }

    @wire(getPicklistValues, { recordTypeId: "$productObjectInfo.data.defaultRecordTypeId", fieldApiName: Family_TYPE_FIELD })
    familyPickList({data, error}){
        if(data){
            this.familyOptions = data.values.map(item => ({label: item.label, value: item.value}));
        }else if(error){
            this.familyOptions = [];
        }
    }

    @wire(getPicklistValues, { recordTypeId: "$productObjectInfo.data.defaultRecordTypeId", fieldApiName: STAGE_TYPE_FIELD })
    stagePickList({data, error}){
        if(data){
            this.stageOptions = data.values.map(item => ({label: item.label, value: item.value}));
        }else if(error){
            this.stageOptions = [];
        }
    }

    @wire(getPicklistValues, { recordTypeId: "$productObjectInfo.data.defaultRecordTypeId", fieldApiName: PREFERRED_BLOCK_FIELD})
    preferredBlockPickList({data, error}){
        if(data){
            this.preferredBlockOptions = data.values.map(item => ({label: item.label, value: item.value}));
        }else if(error){
            this.preferredBlockOptions = [];
        }
    }

    @wire(getPicklistValues, { recordTypeId: "012000000000000AAA", fieldApiName: PRODUCT_TERM_FIELD })
    productTermPicklist({data, error}){
        if(data){
            this.productTermOptions = data.values.map(item => ({label: item.label, value: item.value}));
        }else if(error){
            console.error('Error loading product term picklist:', error);
        }
    }

    
    

    handleBillingTypeChange(event) {
        this.selectedBillingType = event.detail.value;
    }

    handleInstallationTypeChange(event) {
        this.selectedInstallationType = event.detail.value;
    }

    handleProductFamilyChange(event) {
        this.selectedFamily = event.detail.value;
    }

    handleStageChange(event) {
        this.selectedStage = event.detail.value;
    }

    handlePreferredBlockChange(event) {
        this.selectedPreferredBlock = event.detail.value;
    }

    handleProductTermsChange(event) {
        this.selectedProductTerm = event.detail.value;
    }

    @track showModal = false;
    @track modalProducts = [];
    @track selectedProducts = [];
    
    // Third screen modal properties
    @track showThirdScreenModal = false;
    @track selectedProductsForThirdScreen = [];

    handleFilterProducts() {
        this.isLoading = true;
        
        console.log('Filter button clicked with values:', {
            billingType: this.selectedBillingType,
            installationType: this.selectedInstallationType,
            productFamily: this.selectedFamily,
            stageType: this.selectedStage,
            preferredBlock: this.selectedPreferredBlock
        });

        getFilteredProducts({
            billingType: this.selectedBillingType,
            installationType: this.selectedInstallationType,
            productFamily: this.selectedFamily,
            stageType: this.selectedStage,
            preferredBlock: this.selectedPreferredBlock
        })
        .then(result => {
            console.log('Apex returned products:', result);
            
            // Store products for modal
            this.modalProducts = result;
            
            // Open modal with results
            this.showModal = true;
            
            this.showToast('Success', `Found ${result.length} products`, 'success');
            this.isLoading = false;
        })
        .catch(error => {
            console.error('Error in handleFilterProducts:', error);
            this.showToast('Error', 'Error filtering products: ' + (error.body?.message || error.message), 'error');
            this.isLoading = false;
        });
    }

    handleCloseModal() {
        this.showModal = false;
        this.modalProducts = [];
        this.selectedProducts = [];
    }

    handleProductSelection(event) {
        this.selectedProducts = event.detail.selectedProducts;
        console.log('Selected products in modal:', this.selectedProducts);
    }

handleAddSelectedProducts() {
    if (this.selectedProducts.length > 0) {
        this.isAddingProducts = true;
        
        console.log('Selected products for third screen:', this.selectedProducts);
        
        // Show success message
        this.showToast('Success', `${this.selectedProducts.length} products selected`, 'success');
        
        // Close modal
        this.handleCloseModal();
        
        // Navigate to third screen with selected products
        this.navigateToThirdScreen();
        
        this.isAddingProducts = false;
    } else {
        this.showToast('Warning', 'Please select at least one product', 'warning');
    }
}

    navigateToThirdScreen() {
        // Pass selected products to third screen modal
        console.log('filterLineItems - navigateToThirdScreen called');
        console.log('filterLineItems - selectedProducts:', this.selectedProducts);
        console.log('filterLineItems - selectedProducts length:', this.selectedProducts.length);
        
        this.selectedProductsForThirdScreen = [...this.selectedProducts];
        console.log('filterLineItems - selectedProductsForThirdScreen:', this.selectedProductsForThirdScreen);
        
        // Show third screen modal
        this.showThirdScreenModal = true;
    }
    
    handleCloseThirdScreenModal() {
        this.showThirdScreenModal = false;
        this.selectedProductsForThirdScreen = [];
    }
    
    handleOrderSubmitted(event) {
        // Handle successful order submission from third screen
        console.log('Order submitted successfully:', event.detail);
        
        // Close the third screen modal
        this.handleCloseThirdScreenModal();
        
        // Show success message
        this.showToast(
            'Success', 
            'Order created successfully!', 
            'success'
        );
        
        // Reset all data
        this.selectedProducts = [];
        this.selectedProductsForThirdScreen = [];
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    get isAddButtonDisabled() {
        return this.selectedProducts.length === 0 || this.isAddingProducts;
    }
    
    get addButtonLabel() {
        return this.isAddingProducts ? 'Adding...' : 'Add Selected Products';
    }
}
