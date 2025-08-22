# ProductTermComponent Usage Example

## Overview
The `ProductTermComponent` provides a user-friendly interface for selecting product terms with two main payment options: "Upfront" and "Rent to Own". When "Rent to Own" is selected, the component dynamically fetches and displays product terms from the Salesforce `OrderItem.Product_Terms__c` picklist field.

## Features
- **Two Main Options**: Upfront and Rent to Own
- **Dynamic Product Terms**: Fetches product terms from Salesforce when Rent to Own is selected
- **Pill-Style UI**: Modern, responsive design with pill-style buttons
- **Event-Driven**: Dispatches custom events when selections are made
- **State Management**: Maintains selection state and provides public methods for external interaction

## Basic Usage

### 1. In a Parent Component Template
```html
<template>
    <c-product-term-component 
        onmainoption={handleMainOptionChange}
        onproductterm={handleProductTermChange}>
    </c-product-term-component>
</template>
```

### 2. In Parent Component JavaScript
```javascript
import { LightningElement } from 'lwc';

export default class ParentComponent extends LightningElement {
    selectedPaymentType = '';
    selectedProductTerm = '';
    
    handleMainOptionChange(event) {
        const { mainOption, productTerm } = event.detail;
        this.selectedPaymentType = mainOption;
        this.selectedProductTerm = productTerm;
        
        console.log('Payment Type Selected:', mainOption);
        console.log('Product Term Reset:', productTerm);
    }
    
    handleProductTermChange(event) {
        const { mainOption, productTerm } = event.detail;
        this.selectedPaymentType = mainOption;
        this.selectedProductTerm = productTerm;
        
        console.log('Payment Type:', mainOption);
        console.log('Product Term Selected:', productTerm);
    }
    
    // Get current selections from the component
    getCurrentSelection() {
        const productTermComponent = this.template.querySelector('c-product-term-component');
        if (productTermComponent) {
            const selection = productTermComponent.getSelection();
            console.log('Current Selection:', selection);
            return selection;
        }
    }
    
    // Reset the component selection
    resetSelection() {
        const productTermComponent = this.template.querySelector('c-product-term-component');
        if (productTermComponent) {
            productTermComponent.resetSelection();
        }
    }
    
    // Set selection programmatically
    setSelection(mainOption, productTerm) {
        const productTermComponent = this.template.querySelector('c-product-term-component');
        if (productTermComponent) {
            productTermComponent.setSelection(mainOption, productTerm);
        }
    }
}
```

## Component Events

### `mainoption` Event
Dispatched when a main payment type option is selected (Upfront or Rent to Own).

**Event Detail:**
```javascript
{
    mainOption: 'upfront' | 'rent_to_own',
    productTerm: '' // Always empty when main option changes
}
```

### `productterm` Event
Dispatched when a specific product term is selected (only available when Rent to Own is selected).

**Event Detail:**
```javascript
{
    mainOption: 'rent_to_own',
    productTerm: 'selected_product_term_value'
}
```

## Public Methods

### `getSelection()`
Returns the current selection state.
```javascript
const selection = component.getSelection();
// Returns: { mainOption: 'rent_to_own', productTerm: '24_months' }
```

### `resetSelection()`
Clears all selections and resets the component to its initial state.
```javascript
component.resetSelection();
```

### `setSelection(mainOption, productTerm)`
Programmatically sets the component selection.
```javascript
component.setSelection('rent_to_own', '12_months');
```

## Styling
The component uses a modern pill-style design with:
- Responsive layout that adapts to different screen sizes
- Hover and focus states for better accessibility
- Selected state visualization with color changes
- Loading spinner when fetching product terms
- Selection summary display

## Dependencies
- `@salesforce/schema/OrderItem` - For OrderItem object reference
- `@salesforce/schema/OrderItem.Product_Terms__c` - For Product Terms picklist field
- `lightning/uiObjectInfoApi` - For fetching object info and picklist values

## Notes
- The component automatically fetches product terms when the OrderItem object info is available
- Product terms are only displayed when "Rent to Own" is selected
- The component handles loading states gracefully
- All selections are maintained in the component's internal state
- CSS classes are dynamically applied based on selection state

## Example Integration with Filter Component
```javascript
// In a filter component that uses ProductTermComponent
handleProductTermSelection(event) {
    const { mainOption, productTerm } = event.detail;
    
    // Update your filter criteria
    this.filterCriteria.paymentType = mainOption;
    this.filterCriteria.productTerm = productTerm;
    
    // Apply filters or update UI accordingly
    this.applyFilters();
}
```
