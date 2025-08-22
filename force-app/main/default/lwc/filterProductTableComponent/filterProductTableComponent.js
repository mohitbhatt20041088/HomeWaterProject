import { LightningElement, wire, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTotalProductCount from '@salesforce/apex/ProductController.getTotalProductCount';

export default class FilterProductTableComponent extends NavigationMixin (LightningElement){

    // Accept data from parent
    @api filteredProducts;
    @api selectedProductTerm;
    @api zipCode;

    // Images now come from product_image__c rich text field

    /* ── pagination ── */
    pageSize = null;
    currentPage = 1;
    selectedIds = new Set();

    /* ── data ── */
    allRows = [];
    
    // Add component initialization
    connectedCallback() {

        getTotalProductCount()
        .then(data=>{
            console.log('pagesize using Apex =====> ',data);
            this.pageSize = data;
        })
        .catch(error=>{
            console.error('pageSize Data error =====> ',error)
        })



        // Check if this is a fresh session/refresh
        if (this.isFreshSession()) {
            this.clearAllStoredData();
            this.markSessionActive();
        }
        
        // Process filtered products from parent
        if (this.filteredProducts && Array.isArray(this.filteredProducts)) {
            this.processFilteredProducts();
        }
    }

    // Reload selections from localStorage
    reloadSelections() {
        this.loadSelectedProducts();
    }

    // Process filtered products from parent component
    processFilteredProducts() {
        if (this.filteredProducts && Array.isArray(this.filteredProducts)) {
            console.log('Processing filtered products:', this.filteredProducts.length);
            
            this.allRows = this.filteredProducts.map(p => {
                console.log('Product:', p.Name, 'PricebookEntries:', p.PricebookEntries);
                
                let price = 0;
                
                // Try to get price from PricebookEntries
                if (p.PricebookEntries && p.PricebookEntries.length > 0) {
                    price = p.PricebookEntries[0].UnitPrice;
                    console.log('Price from PricebookEntries:', price);
                } 
                // Try to get price from direct price fields
                else if (p.Price__c) {
                    price = p.Price__c;
                    console.log('Price from Price__c:', price);
                } 
                else if (p.List_Price__c) {
                    price = p.List_Price__c;
                    console.log('Price from List_Price__c:', price);
                }
                else if (p.Unit_Price__c) {
                    price = p.Unit_Price__c;
                    console.log('Price from Unit_Price__c:', price);
                }
                else {
                    console.log('No price found for product:', p.Name);
                }
                
                return {
                    ...p,
                    id       : p.Id,
                    name     : p.Name,
                    imageUrl : this.getImageUrl(p.Product_Image__c),
                    Price    : price
                };
            });
            this.currentPage = 1; // reset to first page on new filter
            
            // Always clear selections when new filtered data arrives for better UX
            // This prevents products from being pre-selected when applying new filters
            this.selectedIds = new Set();
            
            // Save filtered products for persistence
            this.saveFilteredProducts();
            
            // Save cleared selections
            this.saveSelectedProducts();
        } else {
            // If no filtered products from parent, try to load from storage
            this.loadFilteredProducts();
            // Only load selections if not a fresh session
            if (!this.isFreshSession()) {
                this.loadSelectedProducts();
            }
        }
    }
    
    // Watch for changes to filteredProducts from parent
    @api
    get filteredProductsData() {
        return this.filteredProducts;
    }
    
    set filteredProductsData(value) {
        this.filteredProducts = value;
        if (value) {
            this.processFilteredProducts();
        }
    }
    
    /* ── data persistence methods ── */
    loadSelectedProducts() {
        try {
            const savedSelections = localStorage.getItem('selectedProductIds');
            if (savedSelections) {
                this.selectedIds = new Set(JSON.parse(savedSelections));
            }
        } catch (error) {
            console.error('Error loading selected products:', error);
        }
    }
    
    saveSelectedProducts() {
        try {
            localStorage.setItem('selectedProductIds', JSON.stringify([...this.selectedIds]));
        } catch (error) {
            console.error('Error saving selected products:', error);
        }
    }
    
    loadFilteredProducts() {
        try {
            const savedProducts = localStorage.getItem('filteredProductsData');
            if (savedProducts) {
                this.allRows = JSON.parse(savedProducts);
            }
        } catch (error) {
            console.error('Error loading filtered products:', error);
        }
    }
    
    saveFilteredProducts() {
        try {
            // Use setTimeout to make localStorage operations non-blocking
            setTimeout(() => {
                // Only save essential data to reduce payload size
                const essentialData = this.allRows.map(product => ({
                    id: product.id,
                    Id: product.Id,
                    name: product.name,
                    Name: product.Name,
                    Price: product.Price,
                    imageUrl: product.imageUrl,
                    // Only include essential fields
                    Billing_Type__c: product.Billing_Type__c,
                    Family: product.Family,
                    Stage__c: product.Stage__c,
                    Preferred_Block__c: product.Preferred_Block__c
                }));
                
                localStorage.setItem('filteredProductsData', JSON.stringify(essentialData));
            }, 0);
        } catch (error) {
            console.error('Error saving filtered products:', error);
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

    getImageUrl(productImageHtml){
        if(!productImageHtml){
            return null;
        }else{
            try{
                const tempDiv = document.createElement('div');
                tempDiv.innerHTML = productImageHtml;

                const imgElement = tempDiv.querySelector('img');
                if(imgElement && imgElement.src){
                    return imgElement.src;
                }
                return null;
            }catch(error){
                console.error('Error extracting image from rich text:',error);
                return null;
                
            }
        }

    }

    /* ── pagination getters ── */
    get totalPages() {
        return Math.ceil(this.allRows.length / this.pageSize);
    }
    get isFirstPage() { return this.currentPage === 1; }
    get isLastPage()  { return this.currentPage === this.totalPages; }

    get currentPageData() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end   = start + this.pageSize;
        return this.allRows.slice(start, end).map(r => {
            const isSelected = this.selectedIds.has(r.id);
            return {
                ...r,
                isSelected: isSelected,
                buttonLabel: isSelected ? 'Selected' : 'Select',
                buttonVariant: isSelected ? 'success' : 'brand'
            };
        });
    }

    /* ── pagination handlers ── */
    handlePrev() {
        // Navigate back to filter screen
        const navigationEvent = new CustomEvent('navigate', {
            detail: { 
                view: 'filter'
            }
        });
        this.dispatchEvent(navigationEvent);
    }
    handleNext() { 
        console.log('handleNext clicked - starting processing');
        
        // Use setTimeout to prevent UI freezing during heavy processing
        setTimeout(() => {
            try {
                // Get selected products
                console.log('Filtering selected products from', this.allRows.length, 'total products');
                const selectedProducts = this.allRows.filter(product => this.selectedIds.has(product.id));
                console.log('Found', selectedProducts.length, 'selected products');
                
                // Add validation: ensure at least one product is selected
                if (selectedProducts.length === 0) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'No Product Selected',
                            message: 'Please select at least one product to proceed.',
                            variant: 'warning',
                        })
                    );
                    return; // Stop execution
                }

                // Optimize selected products data - remove unnecessary fields to reduce payload
                const optimizedSelectedProducts = selectedProducts.map(product => {
                    return {
                        id: product.id,
                        name: product.name,
                        Name: product.Name,
                        Id: product.Id,
                        Price: product.Price,
                        // Include only essential fields to reduce memory usage
                        Billing_Type__c: product.Billing_Type__c,
                        Family: product.Family,
                        Stage__c: product.Stage__c,
                        Preferred_Block__c: product.Preferred_Block__c,
                        Product_Image__c: product.Product_Image__c,
                        imageUrl: product.imageUrl,
                        // Include price-related fields for calculation
                        PricebookEntries: product.PricebookEntries,
                        Price__c: product.Price__c,
                        List_Price__c: product.List_Price__c,
                        Unit_Price__c: product.Unit_Price__c
                    };
                });

                console.log('Dispatching navigation event to parent');
                // Navigate to terms screen with selected products
                const navigationEvent = new CustomEvent('navigate', {
                    detail: { 
                        view: 'terms', 
                        data: optimizedSelectedProducts
                    }
                });
                this.dispatchEvent(navigationEvent);
                console.log('Navigation event dispatched successfully');
                
            } catch (error) {
                console.error('Error in handleNext:', error);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Processing Error',
                        message: 'An error occurred while processing your selection. Please try again.',
                        variant: 'error',
                    })
                );
            }
        }, 10); // Small delay to prevent UI blocking
    }

    /* ── selection handlers ── */
    handleProductSelect(evt) {
        const productId = evt.target.dataset.id;
        
        if (this.selectedIds.has(productId)) {
            this.selectedIds.delete(productId);
        } else {
            this.selectedIds.add(productId);
        }
        
        // Trigger reactivity
        this.selectedIds = new Set(this.selectedIds);
        
        // Save selections to localStorage
        this.saveSelectedProducts();
        
        console.log('Product selection toggled:', productId, 'Selected:', this.selectedIds.has(productId));
    }
}