import { LightningElement, wire, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import Product_Terms__FIELD from '@salesforce/schema/OrderItem.Product_Terms__c';
import getProductPrice from '@salesforce/apex/ProductController.getProductPrice';

export default class ProductDetailPageComponent extends NavigationMixin(LightningElement) {
    
    // Accept data from parent
    @api selectedProducts;
    @api selectedProductTerm;
    @api zipCode;
    
    // Product data
    product;
    products = [];
    selectedProductId;
    
    // Images now come from Product_Image__c rich text field

    // Pricing and form data
    _unitPrice = 0;
    quantities = {};
    productPrices = {}; // Store individual product prices
    productTermOptions = [];
    taxRate = 0.10; // 10% tax
    isLoadingPrice = false;
    hasRendered = false;
    
    // Dynamic calculation for total without tax
    get totalPriceWithoutTax() {
        let total = 0;
        this.products.forEach(product => {
            const quantity = this.quantities[product.Id] || 1;
            const unitPrice = this.productPrices[product.Id] || 0;
            total += unitPrice * quantity;
        });
        return total.toFixed(2);
    }

    // Dynamic calculation for tax amount
    get taxAmount() {
        const subtotal = parseFloat(this.totalPriceWithoutTax);
        const tax = subtotal * this.taxRate;
        return tax.toFixed(2);
    }
    
    // Dynamic calculation for total with tax
    get totalPriceWithTax() {
        const subtotal = parseFloat(this.totalPriceWithoutTax);
        const tax = parseFloat(this.taxAmount);
        const total = subtotal + tax;
        return total.toFixed(2);
    }

    // Add component initialization
    connectedCallback() {
        // Check if this is a fresh session/refresh
        if (this.isFreshSession()) {
            this.clearAllStoredData();
            this.markSessionActive();
        }
        
        // Process selected products from parent or load from storage
        if (this.selectedProducts && Array.isArray(this.selectedProducts) && this.selectedProducts.length > 0) {
            this.processSelectedProducts();
        } else {
            // Try to load from storage if no products from parent
            this.loadProductDetailData();
        }
    }

    handleIndividualQuantityChange(event) {
        const productId = event.target.dataset.productId;
        const quantity = parseInt(event.target.value, 10);
        
        // Ensure quantity is a valid number
        if (!isNaN(quantity) && quantity > 0 && productId) {
            this.quantities = { ...this.quantities, [productId]: quantity };
            this.updateProductSubtotals(); // Update subtotals after quantity change
            this.saveProductDetailData(); // Save updated data
        } else {
            console.error(`Invalid quantity or product ID: ${event.target.value}, ${productId}`);
        }
    }
    
    // Wire to get Product Terms picklist values (same as filter component)
    @wire(getPicklistValues, {
        recordTypeId: '012000000000000AAA', // Default record type
        fieldApiName: Product_Terms__FIELD
    })
    wiredProductTerms({ data, error }) {
        if (data && data.values) {
            this.productTermOptions = data.values.map(v => ({
                label: v?.label || '',
                value: v?.value || ''
            }));
            console.log('Product term options loaded:', this.productTermOptions);
        } else if (error) {
            console.error('Product terms picklist error:', error);
            this.productTermOptions = [];
        }
    }
    
    // Process selected products from parent component
    processSelectedProducts() {
        if (this.selectedProducts && Array.isArray(this.selectedProducts) && this.selectedProducts.length > 0) {
            this.products = this.selectedProducts.map(p => {
                return {
                    ...p,
                    imageUrl: this.getImageUrl(p?.Product_Image__c),
                    unitPrice: '0.00' // Will be updated when prices are fetched
                };
            });
            
            // Save products for persistence
            this.saveProductDetailData();
            
            // Fetch prices for ALL products
            if (this.products.length > 0) {
                this.fetchAllProductPrices();
            }
        } else {
            // Try to load from storage if no products from parent
            this.loadProductDetailData();
        }
        
        // Load saved form data (but don't override if we have a term from parent)
        this.loadFormData();
        
        console.log('Final selectedProductTerm value:', this.selectedProductTerm);
    }
    
    // Watch for changes to selectedProducts from parent
    @api
    get selectedProductsData() {
        return this.selectedProducts;
    }
    
    set selectedProductsData(value) {
        this.selectedProducts = value;
        if (value && value.length > 0) {
            console.log('Product detail received new selectedProducts:', value);
            this.processSelectedProducts();
        } else {
            console.log('Product detail received empty/null selectedProducts, loading from storage');
            this.loadProductDetailData();
        }
    }
    
    // Data persistence methods
    loadFormData() {
        try {
            const savedFormData = localStorage.getItem('productDetailFormData');
            if (savedFormData) {
                const formData = JSON.parse(savedFormData);
                // Only load selectedProductTerm from storage if it's not already set from filter
                if (!this.selectedProductTerm) {
                    this.selectedProductTerm = formData.selectedProductTerm || '';
                }
                this.quantity = formData.quantity || 1;
            }
        } catch (error) {
            console.error('Error loading form data:', error);
        }
    }
    
    saveFormData() {
        try {
            const formData = {
                selectedProductTerm: this.selectedProductTerm,
                quantity: this.quantity
            };
            localStorage.setItem('productDetailFormData', JSON.stringify(formData));
        } catch (error) {
            console.error('Error saving form data:', error);
        }
    }
    
    // Save product detail data for persistence
    saveProductDetailData() {
        try {
            const productDetailData = {
                products: this.products,
                quantities: this.quantities,
                productPrices: this.productPrices
            };
            localStorage.setItem('productDetailData', JSON.stringify(productDetailData));
        } catch (error) {
            console.error('Error saving product detail data:', error);
        }
    }
    
    // Load product detail data from storage
    loadProductDetailData() {
        try {
            const savedData = localStorage.getItem('productDetailData');
            if (savedData) {
                const productDetailData = JSON.parse(savedData);
                this.products = productDetailData.products || [];
                this.quantities = productDetailData.quantities || {};
                this.productPrices = productDetailData.productPrices || {};
            }
        } catch (error) {
            console.error('Error loading product detail data:', error);
        }
    }
    
    clearAllStoredData() {
        localStorage.removeItem('filterCriteriaValues');
        localStorage.removeItem('filteredProductsData');
        localStorage.removeItem('selectedProductIds');
        localStorage.removeItem('productDetailFormData');
        localStorage.removeItem('productDetailData');
    }

    markSessionActive() {
        sessionStorage.setItem('sessionActive', 'true');
    }

    isFreshSession() {
        return !sessionStorage.getItem('sessionActive');
    }
    
    // Extract image URL from Product_Image__c rich text field
    getImageUrl(productImageHtml) {
        if (!productImageHtml) {
            return null; // Return null if no image data
        }
        
        try {
            // Create a temporary DOM element to parse the HTML
            const tempDiv = document.createElement('div');
            tempDiv.innerHTML = productImageHtml;
            
            // Find the first img tag
            const imgElement = tempDiv.querySelector('img');
            if (imgElement && imgElement.src) {
                return imgElement.src;
            }
            
            return null;
        } catch (error) {
            console.error('Error extracting image from rich text:', error);
            return null;
        }
    }
    
    // Handle product term selection
    handleProductTermChange(event) {
        this.selectedProductTerm = event.detail.value;
        this.saveFormData();
        
        // Fetch price when term is selected
        if (this.selectedProductId && this.selectedProductTerm) {
            this.fetchProductPrice();
        }
    }
    
    // Handle quantity change
    handleQuantityChange(event) {
        this.quantity = parseInt(event.detail.value) || 1;
        this.saveFormData();
    }
    
    // Fetch prices for all products
    fetchAllProductPrices() {
        this.isLoadingPrice = true;
        
        const pricePromises = this.products.map(product => 
            getProductPrice({ productId: product.Id })
                .then(price => {
                    this.productPrices = { 
                        ...this.productPrices, 
                        [product.Id]: price || 0 
                    };
                    return { productId: product.Id, price: price || 0 };
                })
                .catch(error => {
                    console.error(`Error fetching price for product ${product.Id}:`, error);
                    this.productPrices = { 
                        ...this.productPrices, 
                        [product.Id]: 0 
                    };
                    return { productId: product.Id, price: 0 };
                })
        );
        
        Promise.all(pricePromises)
            .then(results => {
                console.log('All product prices fetched:', results);
                // Update products array with unitPrice for template display
                this.products = this.products.map(product => ({
                    ...product,
                    unitPrice: (this.productPrices[product.Id] || 0).toFixed(2)
                }));
                this.updateProductSubtotals(); // Update subtotals after fetching prices
                this.saveProductDetailData(); // Save updated data with prices
                this.isLoadingPrice = false;
            })
            .catch(error => {
                console.error('Error fetching all product prices:', error);
                this.isLoadingPrice = false;
            });
    }
    
    // Get unit price for individual product display
    getUnitPrice(productId) {
        const price = this.productPrices[productId] || 0;
        return price.toFixed(2);
    }
    
    // Get subtotal for individual product
    getProductSubtotal(productId) {
        const unitPrice = this.productPrices[productId] || 0;
        const quantity = this.quantities[productId] || 1;
        return (unitPrice * quantity).toFixed(2);
    }
    
    // Update product subtotals
    updateProductSubtotals() {
        if (!this.products || !Array.isArray(this.products)) {
            return;
        }
        
        this.products = this.products.map(product => {
            const unitPrice = parseFloat(this.productPrices[product.Id]) || 0;
            const quantity = parseInt(this.quantities[product.Id], 10) || 1;
            const subtotal = (unitPrice * quantity).toFixed(2);
            return {
                ...product,
                subtotal
            };
        });
    }

    // Handle add to cart - navigate to user detail component
    handleAddToCart() {
        // Prepare product data with quantities and prices
        const productsWithQuantityAndPrice = this.products.map(product => {
            const quantity = this.quantities[product.Id] || 1;
            const unitPrice = this.productPrices[product.Id] || 0;
            
            return {
                ...product,
                quantity: quantity,
                unitPrice: unitPrice,
                subtotal: (quantity * unitPrice).toFixed(2)
            };
        });
        
        console.log('Products with quantity and price:', productsWithQuantityAndPrice);
        
        // Navigate to user detail component with updated product data
        const navigationEvent = new CustomEvent('navigate', {
            detail: { 
                view: 'user-detail',
                data: productsWithQuantityAndPrice // Pass updated product data
            }
        });
        this.dispatchEvent(navigationEvent);
    }
    
    // Handle back to products
    handleBackToProducts() {
        // Navigate back to table screen with selected products data to preserve selections
        const navigationEvent = new CustomEvent('navigate', {
            detail: { 
                view: 'table',
                preserveSelections: true // Flag to indicate selections should be preserved
            }
        });
        this.dispatchEvent(navigationEvent);
    }
    
    // Show toast message
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }
}
