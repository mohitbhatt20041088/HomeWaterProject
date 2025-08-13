import { LightningElement,track,api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createAccountFromUserDetails from '@salesforce/apex/AccountCreationController.createAccountFromUserDetails';
import createAccountAndOrder from '@salesforce/apex/AccountCreationController.createAccountAndOrder';
import { NavigationMixin } from 'lightning/navigation';

export default class UseDetailPageComponent extends NavigationMixin(LightningElement) {
    @api selectedProducts; // Receive selected products from parent
    @api selectedProductTerm; // Receive selected product term from parent
    @api zipCode; // Receive zipcode from parent components
    
    @track firstName = '';
    @track lastName = '';
    @track emailAddress = '';
    @track phoneNumber = '';
    @track address = {
        street: '', city: '', province: '', postalCode: '', country: ''
    };
    @track  isSubmitting = false;
    @track showThankYou = false;


    handleInputChange(event){
        const field = event.target.name;
        this[field] = event.target.value;
    }

    handleAddressChange(event){
        this.address = {...this.address,...event.detail};
    }

    handleBackToProducts(){
        // Navigate back to product detail screen
        const navigationEvent = new CustomEvent('navigate', {
            detail: { 
                view: 'detail'
            }
        });
        this.dispatchEvent(navigationEvent);
    }

    handleCreateOrder(){
        
            if(!this.firstName || !this.lastName || !this.emailAddress || !this.phoneNumber){
                this.showToast('ERROR','Please fill in all required fields: First Name, Last Name, phone and Email','error');
                return;
            }
            this.isSubmitting = true;

            // Debug logging
            console.log('=== CREATE ORDER DEBUG ===');
            console.log('selectedProducts:', this.selectedProducts);
            console.log('selectedProductTerm:', this.selectedProductTerm);
            
            // Prepare selected products data
            const selectedProductsJson = this.selectedProducts ? JSON.stringify(this.selectedProducts) : null;
            console.log('selectedProductsJson:', selectedProductsJson);
            
            // Choose method based on whether we have products or not
            const createMethod = selectedProductsJson ? createAccountAndOrder : createAccountFromUserDetails;
            
            const params = {
                firstName: this.firstName,
                lastName: this.lastName,
                emailAddress: this.emailAddress,
                phoneNumber: this.phoneNumber,
                street: this.address.street,
                city: this.address.city,
                province: this.address.province,
                postalCode: this.address.postalCode,
                country: this.address.country
            };
            
            // Add product data if available
            if(selectedProductsJson) {
                params.selectedProducts = selectedProductsJson;
                params.selectedProductTerm = this.selectedProductTerm;
                params.zipCodeFromComponent = this.zipCode; // Pass zipcode from component
            }

            createMethod(params)
            .then(result=>{
                if(result.startsWith('SUCCESS:')){
                    this.showToast('SUCCESS',result.substring(8),'success');
                    this.resetForm();
                    
                    // Show thank you message inline instead of navigating
                    setTimeout(() => {
                        this.showThankYou = true;
                    }, 1500);
                } else {
                    this.showToast('Error', 'Unexpected response from server', 'error');
                }
            })
            .catch(error=>{
                console.error('Error creating account and order:', error);
                this.showToast('Error', error.body?.message || 'An error occurred while creating the account and order', 'error');
            })
            .finally(() => {
                this.isSubmitting = false;
            });



        
    }


    resetForm() {
        this.firstName = '';
        this.lastName = '';
        this.emailAddress = '';
        this.phoneNumber = '';
        this.address = {
            street: '', city: '', province: '', postalCode: '', country: ''
        };
    }

    showToast(title,message,variant){
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

}
