import { LightningElement, wire, track, api } from 'lwc';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import ORDER_ITEM_OBJECT from '@salesforce/schema/OrderItem';
// Try to import the most likely field API names
import PRODUCT_TERMS_FIELD from '@salesforce/schema/OrderItem.Product_Terms__c';

export default class ProductTermComponent extends LightningElement {
    @track selectedMainOption = ''; // 'upfront' or 'rent_to_own'
    @track selectedProductTerm = '';
    @track productTermOptions = [];
    @track planOptions = [];
    @track isLoading = false;
    @track showValidationMessage = false;
    @track showAddButton = false;
    
    // Main options for the component with enhanced data
    mainOptions = [
        { 
            label: 'Upfront', 
            value: 'upfront',
            description: 'Pay the full amount upfront with no monthly payments',
            isUpfront: true,
            isSelected: false
        },
        { 
            label: 'Rent to Own', 
            value: 'rent_to_own',
            description: 'Flexible monthly payment plans that fit your budget',
            isUpfront: false,
            isSelected: false
        }
    ];
    
    // Base price for calculations - can be set from parent component
    @api basePrice = 1500;

    // Getter for formatted base price
    get formattedBasePrice() {
        return this.basePrice ? this.basePrice.toFixed(2) : '0.00';
    }

    // Initialize component and enable wire service for picklist
    connectedCallback() {
        console.log('ProductTermComponent connected. BasePrice:', this.basePrice);
        this.isLoading = true;
        console.log('Component initialized, waiting for picklist data...');
        
        // Load fallback options immediately to ensure something is always available
        setTimeout(() => {
            if (this.productTermOptions.length === 0) {
                console.log('🔄 No picklist data loaded after timeout, using fallback options');
                this.loadFallbackOptions();
            }
        }, 2000); // Wait 2 seconds for wire service, then fallback
    }

    // Handle main option selection (Upfront vs Rent to Own)
    handleMainOptionChange(event) {
        const selectedValue = event.target.value;
        this.selectedMainOption = selectedValue;
        
        // Reset product term selection when main option changes
        this.selectedProductTerm = '';
        
        console.log('Main option selected:', selectedValue);
        
        // Trigger reactivity
        this.selectedMainOption = selectedValue;
        
        // For Upfront selection, find the correct Upfront value from picklist
        let productTermValue = '';
        if (selectedValue === 'upfront') {
            // Find the Upfront option in the picklist
            const upfrontOption = this.productTermOptions.find(option => 
                option.label && option.label.toLowerCase().includes('upfront')
            );
            productTermValue = upfrontOption ? upfrontOption.value : 'Upfront';
            console.log('Found upfront picklist value:', productTermValue);
        }
        
        // Dispatch custom event to parent component
        this.dispatchEvent(new CustomEvent('mainoption', {
            detail: {
                mainOption: selectedValue,
                productTerm: productTermValue
            }
        }));
        
        // Also dispatch productterm event to ensure parent component clears the value
        this.dispatchEvent(new CustomEvent('productterm', {
            detail: {
                mainOption: selectedValue,
                productTerm: productTermValue
            }
        }));
    }
    
    // Handle plan selection (simple version)
    handlePlanSelect(event) {
        const selectedValue = event.currentTarget.dataset.value;
        this.selectedProductTerm = selectedValue;
        
        console.log('Plan selected:', selectedValue);
        
        // Dispatch custom event to parent component
        this.dispatchEvent(new CustomEvent('productterm', {
            detail: {
                mainOption: this.selectedMainOption,
                productTerm: selectedValue
            }
        }));
    }

    // Handle product term selection (when Rent to Own is selected)
    handleProductTermChange(event) {
        const selectedValue = event.currentTarget.dataset.value;
        this.selectedProductTerm = selectedValue;
        
        // Update button classes
        this.updateButtonClasses();
        
        console.log('Product term selected:', selectedValue);
        
        // Dispatch custom event to parent component
        this.dispatchEvent(new CustomEvent('productterm', {
            detail: {
                mainOption: this.selectedMainOption,
                productTerm: selectedValue
            }
        }));
    }
    
    // Handle radio button plan selection
    handlePlanChange(event) {
        const selectedValue = event.target.value;
        
        // Reset if "none" is selected
        if (selectedValue === 'none') {
            this.selectedProductTerm = '';
        } else {
            this.selectedProductTerm = selectedValue;
        }
        
        console.log('Plan selected:', selectedValue);
        
        // Hide validation message when a plan is selected
        this.showValidationMessage = false;
        
        // Dispatch custom event to parent component
        this.dispatchEvent(new CustomEvent('productterm', {
            detail: {
                mainOption: this.selectedMainOption,
                productTerm: selectedValue === 'none' ? '' : selectedValue
            }
        }));
    }
    
    // Calculate monthly price based on actual selected products total with tax
    calculateMonthlyPrice(months) {
        if (months <= 0) {
            return '0.00';
        }
        
        // Use the actual total price from selected products (basePrice from parent)
        // This should include tax and be the total of all selected products
        const totalPriceWithTax = this.basePrice || 0;
        
        if (totalPriceWithTax <= 0) {
            return '0.00';
        }
        
        // Simple division: Total price divided by number of months
        const monthlyPayment = totalPriceWithTax / months;
        
        return monthlyPayment.toFixed(2);
    }

    // Getter to check if Rent to Own is selected
    get isRentToOwnSelected() {
        const isSelected = this.selectedMainOption === 'rent_to_own';
        // Initialize planOptions when Rent to Own is selected
        if (isSelected && this.planOptions.length === 0) {
            this.initializePlanOptions();
        }
        return isSelected;
    }
    
    // Computed property for dynamic plan options that recalculates when basePrice changes
    get dynamicPlanOptions() {
        if (this.productTermOptions.length === 0) {
            return [];
        }
        
        const dynamicPlanOptions = [];
        
        // Add "None" option first
        dynamicPlanOptions.push({
            label: 'None',
            value: 'none',
            price: null,
            showPrice: false,
            showQuantity: false,
            radioId: 'plan-none',
            formattedPrice: '0.00'
        });
        
        // Add dynamic options from picklist with current basePrice calculations
        this.productTermOptions.forEach(option => {
            const months = option.months || parseInt(option.value);
            if (!isNaN(months)) {
                const monthlyPrice = parseFloat(this.calculateMonthlyPrice(months));
                dynamicPlanOptions.push({
                    label: option.label,
                    value: option.value,
                    price: monthlyPrice,
                    showPrice: true,
                    showQuantity: false,
                    radioId: option.radioId,
                    formattedPrice: monthlyPrice.toFixed(2)
                });
            }
        });
        
        console.log('Dynamic plan options calculated with basePrice:', this.basePrice, dynamicPlanOptions);
        return dynamicPlanOptions;
    }
    
    // Initialize plan options from picklist values
    initializePlanOptions() {
        // Use the dynamic plan options getter
        this.planOptions = this.dynamicPlanOptions;
        
        // Show validation message initially
        this.showValidationMessage = true;
        
        console.log('Plan options initialized from picklist:', this.planOptions);
    }
    
    // Computed property to determine if Add button should be disabled
    get isAddDisabled() {
        return !this.selectedProductTerm;
    }
    
    // Handle Add to Cart button click
    handleAddToCart() {
        if (!this.selectedProductTerm) {
            this.showValidationMessage = true;
            return;
        }
        
        // Hide validation message
        this.showValidationMessage = false;
        
        // Find selected plan details from dynamic plan options
        const selectedPlan = this.dynamicPlanOptions.find(plan => plan.value === this.selectedProductTerm);
        
        // Dispatch custom event with selected plan details
        this.dispatchEvent(new CustomEvent('addtocart', {
            detail: {
                mainOption: this.selectedMainOption,
                productTerm: this.selectedProductTerm,
                planDetails: selectedPlan
            }
        }));
        
        console.log('Add to cart clicked with selection:', {
            mainOption: this.selectedMainOption,
            productTerm: this.selectedProductTerm,
            planDetails: selectedPlan
        });
    }

    // Getter to check if main option is selected
    isMainOptionSelected(value) {
        return this.selectedMainOption === value;
    }

    // Getter to check if product term is selected
    isProductTermSelected(value) {
        return this.selectedProductTerm === value;
    }

    // Get CSS class for main option pills
    getMainOptionClass(value) {
        return this.selectedMainOption === value ? 'pill-button selected' : 'pill-button';
    }

    // Get CSS class for product term pills
    getProductTermClass(value) {
        return this.selectedProductTerm === value ? 'pill-button selected' : 'pill-button';
    }

    // Public method to get current selection
    getSelection() {
        return {
            mainOption: this.selectedMainOption,
            productTerm: this.selectedProductTerm
        };
    }

    // Public method to reset selection
    resetSelection() {
        this.selectedMainOption = '';
        this.selectedProductTerm = '';
    }

    // Public method to set selection programmatically
    setSelection(mainOption, productTerm = '') {
        this.selectedMainOption = mainOption || '';
        this.selectedProductTerm = productTerm || '';
        this.updateButtonClasses();
    }

    // Method to update button classes after selection changes
    updateButtonClasses() {
        // Update main option button classes
        const mainButtons = this.template.querySelectorAll('[data-type="main-option"]');
        mainButtons.forEach(button => {
            const buttonValue = button.dataset.value;
            if (buttonValue === this.selectedMainOption) {
                button.classList.add('selected');
            } else {
                button.classList.remove('selected');
            }
        });

        // Update product term button classes
        const termButtons = this.template.querySelectorAll('[data-type="product-term"]');
        termButtons.forEach(button => {
            const buttonValue = button.dataset.value;
            if (buttonValue === this.selectedProductTerm) {
                button.classList.add('selected');
            } else {
                button.classList.remove('selected');
            }
        });
    }
    
    // Method to update radio button option styling
    updateRadioButtonStyles() {
        // Wait for next tick to ensure DOM is updated
        setTimeout(() => {
            const planOptions = this.template.querySelectorAll('.plan-option');
            planOptions.forEach(option => {
                const radio = option.querySelector('.plan-radio');
                if (radio && radio.checked) {
                    option.classList.add('selected-option');
                } else {
                    option.classList.remove('selected-option');
                }
            });
        }, 0);
    }

    // Lifecycle method to update classes after render
    renderedCallback() {
        this.updateButtonClasses();
        this.updateMainOptionSelectionState();
    }

    // Navigation methods
    handleBackToProducts() {
        console.log('Navigating back to products');
        // Dispatch navigate event to match parent component expectations
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: {
                view: 'table',
                preserveSelections: true
            }
        }));
    }

    handleNext() {
        if (this.isNextDisabled) {
            // Show validation if needed
            if (this.selectedMainOption === 'rent_to_own' && !this.selectedProductTerm) {
                this.showValidationMessage = true;
            }
            return;
        }

        console.log('Proceeding to next step with selection:', {
            mainOption: this.selectedMainOption,
            productTerm: this.selectedProductTerm
        });

        // Hide validation message
        this.showValidationMessage = false;

        // For upfront payments, find and use the correct upfront picklist value
        let finalProductTerm = this.selectedProductTerm;
        if (this.selectedMainOption === 'upfront') {
            const upfrontOption = this.productTermOptions.find(option => 
                option.label && option.label.toLowerCase().includes('upfront')
            );
            finalProductTerm = upfrontOption ? upfrontOption.value : 'Upfront';
            console.log('Using upfront picklist value for navigation:', finalProductTerm);
        }

        // Dispatch navigate event to match parent component expectations
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: {
                view: 'detail',
                selectedTerms: {
                    mainOption: this.selectedMainOption,
                    productTerm: finalProductTerm
                },
                planDetails: this.selectedMainOption === 'rent_to_own' ? 
                    this.dynamicPlanOptions.find(plan => plan.value === this.selectedProductTerm) : null
            }
        }));
    }

    // Getter to determine if Next button should be disabled
    get isNextDisabled() {
        if (!this.selectedMainOption) {
            return true;
        }
        
        // If Rent to Own is selected, must also select a payment plan
        if (this.selectedMainOption === 'rent_to_own' && !this.selectedProductTerm) {
            return true;
        }
        
        return false;
    }

    // Method to update main option selection state
    updateMainOptionSelectionState() {
        this.mainOptions = this.mainOptions.map(option => ({
            ...option,
            isSelected: option.value === this.selectedMainOption
        }));
    }
    
    // Wire service to get OrderItem object info
    @wire(getObjectInfo, { objectApiName: ORDER_ITEM_OBJECT })
    orderItemObjectInfo;
    
    // Wire service to get Product Terms picklist - trying the most common field name
    @wire(getPicklistValues, {
        recordTypeId: "$orderItemObjectInfo.data.defaultRecordTypeId",
        fieldApiName: PRODUCT_TERMS_FIELD
    })
    wiredProductTermPicklist({ error, data }) {
        console.log('=== PRODUCT TERMS PICKLIST WIRE SERVICE ===' );
        console.log('Data received:', data);
        console.log('Error received:', error);
        console.log('OrderItem object info:', this.orderItemObjectInfo.data);
        
        if (data && data.values && data.values.length > 0) {
            console.log('SUCCESS: Product Terms picklist data received!');
            console.log('Picklist values:', data.values);
            
            // Process the real picklist values
            this.productTermOptions = data.values.map((option, index) => {
                // Extract number from label (e.g., "12 Months" -> 12, "3 Month Plan" -> 3)
                const monthsMatch = option.label.match(/\d+/);
                const months = monthsMatch ? parseInt(monthsMatch[0]) : (index + 1) * 6; // fallback: 6, 12, 18, etc.
                
                console.log(`Processing picklist option: ${option.label} -> ${months} months`);
                
                return {
                    label: option.label,
                    value: option.value, 
                    months: months,
                    radioId: `plan-${option.value}`,
                    monthlyPrice: this.calculateMonthlyPrice(months)
                };
            });
            
            this.isLoading = false;
            console.log('✅ Real Product Term options processed successfully:', this.productTermOptions);
            
        } else if (error) {
            console.error('❌ Error loading Product Terms picklist:', error);
            console.error('Error details:', JSON.stringify(error, null, 2));
            
            // Check what fields are available to help with debugging
            if (this.orderItemObjectInfo.data && this.orderItemObjectInfo.data.fields) {
                const fieldNames = Object.keys(this.orderItemObjectInfo.data.fields);
                console.log('📋 All OrderItem fields:', fieldNames);
                
                const termFields = fieldNames.filter(f => 
                    f.toLowerCase().includes('term') || 
                    f.toLowerCase().includes('product')
                );
                console.log('🔍 Fields containing "term" or "product":', termFields);
            }
            
            console.log('⚠️ Using fallback options due to picklist error...');
            this.loadFallbackOptions();
            
        } else {
            console.log('⏳ No data and no error - wire service may still be loading...');
            
            // If we've been waiting and still no data, use fallback immediately
            setTimeout(() => {
                if (this.productTermOptions.length === 0) {
                    console.log('⚠️ Timeout: Wire service not providing data, loading fallback options');
                    this.loadFallbackOptions();
                }
            }, 1000);
        }
    }
    
    
    // Load fallback options when picklist fails - using REAL Salesforce picklist values!
    loadFallbackOptions() {
        console.log('📦 Loading REAL Product Term picklist values from Salesforce metadata...');
        
        // These are the EXACT values from your OrderItem.Product_Terms__c field
        const realPicklistValues = [
            { label: '2', value: '2', months: 2 },
            { label: '3', value: '3', months: 3 },
            { label: '4', value: '4', months: 4 },
            { label: '5', value: '5', months: 5 },
            { label: '6', value: '6', months: 6 },
            { label: '7', value: '7', months: 7 },
            { label: '8', value: '8', months: 8 },
            { label: '9', value: '9', months: 9 },
            { label: '10', value: '10', months: 10 },
            { label: '11', value: '11', months: 11 },
            { label: '12', value: '12', months: 12 },
            { label: '13', value: '13', months: 13 },
            { label: '14', value: '14', months: 14 },
            { label: '15', value: '15', months: 15 },
            { label: '16', value: '16', months: 16 },
            { label: '17', value: '17', months: 17 },
            { label: '18', value: '18', months: 18 },
            { label: '19', value: '19', months: 19 },
            { label: '20', value: '20', months: 20 },
            { label: '21', value: '21', months: 21 },
            { label: '22', value: '22', months: 22 },
            { label: '23', value: '23', months: 23 },
            { label: '24', value: '24', months: 24 },
            { label: '25', value: '25', months: 25 },
            { label: '26', value: '26', months: 26 },
            { label: '27', value: '27', months: 27 },
            { label: '28', value: '28', months: 28 },
            { label: '29', value: '29', months: 29 },
            { label: '30', value: '30', months: 30 },
            { label: '31', value: '31', months: 31 },
            { label: '32', value: '32', months: 32 },
            { label: '33', value: '33', months: 33 },
            { label: '34', value: '34', months: 34 },
            { label: '35', value: '35', months: 35 },
            { label: '36', value: '36', months: 36 }
        ];
        
        // Convert to component format with pricing
        this.productTermOptions = realPicklistValues.map(option => ({
            label: `${option.months} Months`,
            value: option.value,
            months: option.months,
            radioId: `plan-${option.value}`,
            monthlyPrice: this.calculateMonthlyPrice(option.months)
        }));
        
        this.isLoading = false;
        console.log('✅ REAL Salesforce picklist options loaded successfully:', this.productTermOptions);
        console.log('🔢 Total options available:', this.productTermOptions.length);
        
        // Force template to re-render
        this.planOptionsForTemplate; // Trigger getter evaluation
    }
    
    // Dynamic computed properties based on picklist data
    get planOptionsForTemplate() {
        return this.productTermOptions.map(option => ({
            ...option,
            monthlyPrice: this.calculateMonthlyPrice(option.months)
        }));
    }
}
