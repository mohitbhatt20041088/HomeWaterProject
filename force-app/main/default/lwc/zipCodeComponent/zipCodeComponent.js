import { LightningElement, track } from 'lwc';
import checkServiceability from '@salesforce/apex/AccountCreationController.isZipCodeServiceable';

export default class ZipCodeComponent extends LightningElement {
    @track zipCode = '';
    @track isVerifying = false;
    @track isVerificationComplete = false; // New state for controlling the screen
    @track isServiceable = false;
    @track serviceabilityMessage = '';
    @track showFilterComponent = false; // New state to control filter component visibility
    @track hasValidationError = false; // Track validation errors
    @track validationMessage = ''; // Store validation error message

    // Handle zip code input change
    handleZipCodeChange(event) {
        this.zipCode = event.target.value;
        // Reset validation states when user types
        this.resetValidationStates();
        this.isVerificationComplete = false; // Ensure verification screen is hidden
        console.log('Zip code entered:', this.zipCode);
    }

    // Handle verify button click
    handleVerifyZipCode() {
        // Validate zipcode is not blank
        if (!this.validateZipCode()) {
            return; // Stop execution if validation fails
        }
        this.checkZipCodeServiceability();
    }

    // Check serviceability using Apex controller
    checkZipCodeServiceability() {
        this.isVerifying = true;
        this.resetValidationStates();

        checkServiceability({ zipCode: this.zipCode.trim() })
            .then(result => {
                this.isServiceable = result;
                
                if (result) {
                    this.serviceabilityMessage = 'This is a serviceable area , you can select the Tech Install products';
                } else {
                    this.serviceabilityMessage = 'Sorry, this is not a serviceable area. please select for self install products';
                }
            })
            .catch(error => {
                console.error('Error checking serviceability:', error);
                this.isServiceable = false;
                this.serviceabilityMessage = 'Error checking serviceability. Please try again.';
            })
            .finally(() => {
                this.isVerifying = false;
                this.isVerificationComplete = true;
            });
    }

    // Handle back button click
    handleBackToInput() {
        this.isVerificationComplete = false;
    }

    // Reset validation states
    resetValidationStates() {
        this.isServiceable = false;
        this.serviceabilityMessage = '';
        this.hasValidationError = false;
        this.validationMessage = '';
    }


    // Handle next button click to show filter component
    handleNext() {
        // Dispatch zipcode to parent/child components
        const zipEvent = new CustomEvent('zipselected', {
            detail: { zipCode: this.zipCode }
        });
        this.dispatchEvent(zipEvent);
        this.showFilterComponent = true;
    }

    // Handle back from filter component
    handleBackFromFilter() {
        this.showFilterComponent = false;
    }

    // Validate zipcode input
    validateZipCode() {
        // Reset validation state
        this.hasValidationError = false;
        this.validationMessage = '';

        // Check if zipcode is blank or only whitespace
        if (!this.zipCode || this.zipCode.trim().length === 0) {
            this.hasValidationError = true;
            this.validationMessage = 'Please enter a zip code before verifying.';
            return false;
        }

        // Optional: Check for minimum length (US zip codes are at least 5 digits)
        const cleanZipCode = this.zipCode.trim();
        if (cleanZipCode.length < 5) {
            this.hasValidationError = true;
            this.validationMessage = 'Zip code must be at least 5 characters long.';
            return false;
        }

        // Optional: Basic format validation (digits, optional dash and more digits)
       /* const zipCodePattern = /^\d{5}(-\d{4})?$/;
        if (!zipCodePattern.test(cleanZipCode)) {
            this.hasValidationError = true;
            this.validationMessage = 'Please enter a valid zip code format (e.g., 12345 or 12345-6789).';
            return false;
        }*/

        return true;
    }
}
