import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import createFullOrder from '@salesforce/apex/CreateSalesRecordsController.createFullOrder';

const productColumns = [
    { label: 'Product Name', fieldName: 'Name', wrapText: true },
    { label: 'Product Code', fieldName: 'ProductCode' },
];

export default class ThirdScreen extends LightningElement {
    // Form data properties
    @track formData = {
        firstName: '',
        lastName: '',
        email: '',
        phone: '',
        address: ''
    };
    @track selectedProductIds = [];

    // LWC state properties
    isLoading = false;
    products = [];
    productColumns = productColumns;

    @api 
    get selectedProducts() {
        return this._selectedProducts || [];
    }
    
    set selectedProducts(value) {
        console.log('thirdScreen - selectedProducts setter called with:', value);
        this._selectedProducts = value;
        // Automatically update selectedProductIds when selectedProducts changes
        if (this._selectedProducts && this._selectedProducts.length > 0) {
            this.selectedProductIds = this._selectedProducts.map(product => product.Id);
            console.log('thirdScreen - Updated selectedProductIds:', this.selectedProductIds);
        } else {
            console.log('thirdScreen - No products received or empty array');
            this.selectedProductIds = [];
        }
    }
    
    _selectedProducts = [];

    get hasProducts() {
        return this.selectedProducts && this.selectedProducts.length > 0;
    }

connectedCallback() {
    // Retrieve selected products from localStorage if available
    const storedProducts = localStorage.getItem('selectedProductsForOrder');
    if (storedProducts) {
        try {
            this.selectedProducts = JSON.parse(storedProducts);
            if (this.selectedProducts && this.selectedProducts.length > 0) {
                this.selectedProductIds = this.selectedProducts.map(product => product.Id);
            }
        } catch (error) {
            console.error('Error parsing stored products:', error);
        }
    }
    
    // Also populate selectedProductIds if selectedProducts is passed via API
    if (this.selectedProducts && this.selectedProducts.length > 0) {
        this.selectedProductIds = this.selectedProducts.map(product => product.Id);
    }
}

    // Getter to disable the submit button until all required fields are filled
    get isSubmitDisabled() {
        return !this.formData.firstName ||
               !this.formData.lastName ||
               !this.formData.email ||
               !this.formData.phone ||
               !this.formData.address;
    }

    // Handlers for user input
    handleInputChange(event) {
        const { name, value } = event.target;
        this.formData = { ...this.formData, [name]: value };
    }

    handleRowSelection(event) {
        // Extract product IDs from selected products
        if(this.selectedProducts){
            this.selectedProductIds = this.selectedProducts.map(product => product.Id);
        }
    }

    // Main submit logic
    async handleSubmit() {
        this.isLoading = true;
        
        console.log('Selected Products:', this.selectedProducts);
        console.log('Selected Product IDs:', this.selectedProductIds);
        
        const request = {
            firstName: this.formData.firstName,
            lastName: this.formData.lastName,
            email: this.formData.email,
            phone: this.formData.phone,
            address: this.formData.address,
            selectedProductIds: this.selectedProductIds
        };
        
        console.log('Request being sent to Apex:', request);

        try {
            const opportunityId = await createFullOrder({ request: request });
            this.showToast(
                'Success',
                `Successfully created records. Opportunity ID: ${opportunityId}`,
                'success'
            );
            
            // Dispatch event to parent component
            const orderSubmittedEvent = new CustomEvent('ordersubmitted', {
                detail: { 
                    opportunityId: opportunityId,
                    message: 'Order created successfully'
                }
            });
            this.dispatchEvent(orderSubmittedEvent);
            
            // Reset the form after successful submission
            this.resetForm();
        } catch (error) {
            const errorMessage = error.body ? error.body.message : 'An unknown error occurred.';
            this.showToast('Error', errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Helper functions
    resetForm() {
        this.formData = { firstName: '', lastName: '', email: '', phone: '', address: '' };
        this.selectedProductIds = [];
        this.selectedProducts = [];
        
        // Clear localStorage
        localStorage.removeItem('selectedProductsForOrder');
        
        // Reset all input fields in the template
        this.template.querySelectorAll('lightning-input, lightning-combobox').forEach(element => {
            element.value = null;
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}