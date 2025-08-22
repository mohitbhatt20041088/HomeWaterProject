import { LightningElement, wire, api, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getPicklistValues, getObjectInfo } from "lightning/uiObjectInfoApi";
import Product_Terms__FIELD from "@salesforce/schema/OrderItem.Product_Terms__c";
import PRODUCT2_OBJECT from "@salesforce/schema/Product2";
import BILLING_TYPE_FIELD from "@salesforce/schema/Product2.Billing_Type__c";
import Family_FIELD from "@salesforce/schema/Product2.Family";
import Stage__FIELD from "@salesforce/schema/Product2.Stage__c";
import Preferred_Block__FIELD from "@salesforce/schema/Product2.Preferred_Block__c";
import getProductPrice from "@salesforce/apex/ProductController.getProductPrice";
import getRecommendedProducts from "@salesforce/apex/FilterProductsHelper.getRecommendedProducts";

export default class ProductDetailPageComponent extends NavigationMixin(
  LightningElement
) {
  // Accept data from parent
  @api selectedProducts;
  @api selectedProductTerm;
  @api zipCode;

  _selectedBillingType;
  _selectedFamilyType;
  _selectedStageType;
  _selectedPreferredBlockType;
  _selectedMainOption;

  @api
  get selectedBillingType() {
    return this._selectedBillingType;
  }
  set selectedBillingType(value) {
    this._selectedBillingType = value;
    this.fetchRecommendedProducts();
  }

  @api
  get selectedFamilyType() {
    return this._selectedFamilyType;
  }
  set selectedFamilyType(value) {
    this._selectedFamilyType = value;
    this.fetchRecommendedProducts();
  }

  @api
  get selectedStageType() {
    return this._selectedStageType;
  }
  set selectedStageType(value) {
    this._selectedStageType = value;
    this.fetchRecommendedProducts();
  }

  @api
  get selectedPreferredBlockType() {
    return this._selectedPreferredBlockType;
  }
  set selectedPreferredBlockType(value) {
    this._selectedPreferredBlockType = value;
    this.fetchRecommendedProducts();
  }

  @track recommendedProducts = [];
  @track filteredRecommendedProducts = [];

  // Enhanced Slider functionality
  @track currentSlideIndex = 0;
  @track itemsPerSlide = 3; // Number of products to show per slide
  @track sliderIndicators = [];
  @track isAutoPlaying = true; // Start with autoplay enabled by default
  @track autoPlayInterval = null;
  @track touchStartX = 0;
  @track touchEndX = 0;

  // Advanced filtering
  @track searchTerm = "";
  @track activeFilters = [];
  @track showAdvancedFilters = false;
  @track viewAllMode = false;
  @track debounceTimeout = null;

  // UI state management
  @track isRecommendationsPanelOpen = false;

  // Store original filter values from parent for reset functionality
  @track originalBillingType;
  @track originalFamilyType;
  @track originalStageType;
  @track originalPreferredBlockType;

  // Track if user has modified slider filters
  @track hasUserModifiedFilters = false;

  // Filter options for dropdowns
  @track billingTypeFilterOptions = [];
  @track familyTypeFilterOptions = [];
  @track stageTypeFilterOptions = [];
  @track preferredBlockTypeFilterOptions = [];

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
  taxRate = 0.1; // 10% tax
  isLoadingPrice = false;
  hasRendered = false;

  

  get excludedProductIds() {
    return this.products.map((p) => p.Id);
  }

  // Dynamic calculation for total without tax
  get totalPriceWithoutTax() {
    let total = 0;
    this.products.forEach((product) => {
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
    if (
      this.selectedProducts &&
      Array.isArray(this.selectedProducts) &&
      this.selectedProducts.length > 0
    ) {
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
      console.error(
        `Invalid quantity or product ID: ${event.target.value}, ${productId}`
      );
    }
  }

  // Wire to get Product Terms picklist values (same as filter component)
  @wire(getPicklistValues, {
    recordTypeId: "012000000000000AAA", // Default record type
    fieldApiName: Product_Terms__FIELD
  })
  wiredProductTerms({ data, error }) {
    if (data && data.values) {
      // Use the existing picklist values which already includes Upfront
      this.productTermOptions = data.values.map((v) => ({
        label: v?.label || "",
        value: v?.value || ""
      }));
      console.log(
        "Product term options loaded from picklist:",
        this.productTermOptions
      );
    } else if (error) {
      console.error("Product terms picklist error:", error);
      this.productTermOptions = [];
    }
  }

  

  // Watch for changes to selectedProducts from parent
  @api
  get selectedProductsData() {
    return this.selectedProducts;
  }

  set selectedProductsData(value) {
    this.selectedProducts = value;
    if (value && value.length > 0) {
      console.log("Product detail received new selectedProducts:", value);
      this.processSelectedProducts();
    } else {
      console.log(
        "Product detail received empty/null selectedProducts, loading from storage"
      );
      this.loadProductDetailData();
    }
  }

  // Add this API property to properly handle upfront selection
  @api
  get selectedMainOption() {
    return this._selectedMainOption;
  }
  set selectedMainOption(value) {
    this._selectedMainOption = value;
    console.log("Main option updated in product detail:", value);
    // If main option is set to 'upfront', find the correct Upfront value from picklist
    if (value === "upfront") {
      // Wait for picklist to load, then find the upfront option
      setTimeout(() => {
        const upfrontOption = this.productTermOptions.find(
          (option) =>
            option.label && option.label.toLowerCase().includes("upfront")
        );
        if (upfrontOption) {
          this.selectedProductTerm = upfrontOption.value;
          console.log(
            "Setting product term to picklist Upfront value:",
            upfrontOption.value
          );
        } else {
          // Fallback if no upfront option found in picklist
          this.selectedProductTerm = "Upfront";
          console.log("Using fallback Upfront value");
        }
      }, 100);
    }
  }

  // Data persistence methods
  loadFormData() {
    try {
      const savedFormData = localStorage.getItem("productDetailFormData");
      if (savedFormData) {
        const formData = JSON.parse(savedFormData);
        // Only load selectedProductTerm from storage if it's not already set from filter
        if (!this.selectedProductTerm) {
          this.selectedProductTerm = formData.selectedProductTerm || "";
        }
        this.quantity = formData.quantity || 1;
      }
    } catch (error) {
      console.error("Error loading form data:", error);
    }
  }

  saveFormData() {
    try {
      const formData = {
        selectedProductTerm: this.selectedProductTerm,
        quantity: this.quantity
      };
      localStorage.setItem("productDetailFormData", JSON.stringify(formData));
    } catch (error) {
      console.error("Error saving form data:", error);
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
      localStorage.setItem(
        "productDetailData",
        JSON.stringify(productDetailData)
      );
    } catch (error) {
      console.error("Error saving product detail data:", error);
    }
  }

  // Load product detail data from storage
  loadProductDetailData() {
    try {
      const savedData = localStorage.getItem("productDetailData");
      if (savedData) {
        const productDetailData = JSON.parse(savedData);
        this.products = productDetailData.products || [];
        this.quantities = productDetailData.quantities || {};
        this.productPrices = productDetailData.productPrices || {};
      }
    } catch (error) {
      console.error("Error loading product detail data:", error);
    }
  }

  clearAllStoredData() {
    localStorage.removeItem("filterCriteriaValues");
    localStorage.removeItem("filteredProductsData");
    localStorage.removeItem("selectedProductIds");
    localStorage.removeItem("productDetailFormData");
    localStorage.removeItem("productDetailData");
  }

  markSessionActive() {
    sessionStorage.setItem("sessionActive", "true");
  }

  isFreshSession() {
    return !sessionStorage.getItem("sessionActive");
  }

  // Extract image URL from Product_Image__c rich text field
  getImageUrl(productImageHtml) {
    if (!productImageHtml) {
      return null; // Return null if no image data
    }

    try {
      // Create a temporary DOM element to parse the HTML
      const tempDiv = document.createElement("div");
      tempDiv.innerHTML = productImageHtml;

      // Find the first img tag
      const imgElement = tempDiv.querySelector("img");
      if (imgElement && imgElement.src) {
        return imgElement.src;
      }

      return null;
    } catch (error) {
      console.error("Error extracting image from rich text:", error);
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

    const pricePromises = this.products.map((product) =>
      getProductPrice({ productId: product.Id })
        .then((price) => {
          this.productPrices = {
            ...this.productPrices,
            [product.Id]: price || 0
          };
          return { productId: product.Id, price: price || 0 };
        })
        .catch((error) => {
          console.error(
            `Error fetching price for product ${product.Id}:`,
            error
          );
          this.productPrices = {
            ...this.productPrices,
            [product.Id]: 0
          };
          return { productId: product.Id, price: 0 };
        })
    );

    Promise.all(pricePromises)
      .then((results) => {
        console.log("All product prices fetched:", results);
        // Update products array with unitPrice for template display
        this.products = this.products.map((product) => ({
          ...product,
          unitPrice: (this.productPrices[product.Id] || 0).toFixed(2)
        }));
        this.updateProductSubtotals(); // Update subtotals after fetching prices
        this.saveProductDetailData(); // Save updated data with prices
        this.isLoadingPrice = false;
      })
      .catch((error) => {
        console.error("Error fetching all product prices:", error);
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

    this.products = this.products.map((product) => {
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
    const productsWithQuantityAndPrice = this.products.map((product) => {
      const quantity = this.quantities[product.Id] || 1;
      const unitPrice = this.productPrices[product.Id] || 0;

      return {
        ...product,
        quantity: quantity,
        unitPrice: unitPrice,
        subtotal: (quantity * unitPrice).toFixed(2)
      };
    });

    console.log(
      "Products with quantity and price:",
      productsWithQuantityAndPrice
    );

    // Navigate to user detail component with updated product data
    const navigationEvent = new CustomEvent("navigate", {
      detail: {
        view: "user-detail",
        data: productsWithQuantityAndPrice // Pass updated product data
      }
    });
    this.dispatchEvent(navigationEvent);
  }

  // Handle back to terms
  handleBackToTerms() {
    // Navigate back to terms screen
    const navigationEvent = new CustomEvent("navigate", {
      detail: {
        view: "terms"
      }
    });
    this.dispatchEvent(navigationEvent);
  }

  // Handle back to products
  handleBackToProducts() {
    // Navigate back to table screen with selected products data to preserve selections
    const navigationEvent = new CustomEvent("navigate", {
      detail: {
        view: "table",
        preserveSelections: true // Flag to indicate selections should be preserved
      }
    });
    this.dispatchEvent(navigationEvent);
  }

  // Computed property for payment method label
  get paymentMethodLabel() {
    // This should come from the parent component's selected main option
    return "Rent to Own"; // Default for now, can be made dynamic
  }

  // Computed property for selected product term label
  get selectedProductTermLabel() {
    if (!this.selectedProductTerm || !this.productTermOptions) {
      return "Not Selected";
    }

    const selectedOption = this.productTermOptions.find(
      (option) => option.value === this.selectedProductTerm
    );

    return selectedOption ? selectedOption.label : this.selectedProductTerm;
  }

  // Show toast message
  showToast(title, message, variant) {
    const event = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant,
      mode: "dismissable"
    });
    this.dispatchEvent(event);
  }

  extractProductPrice(product) {
    console.log("Extracting price for product:", product.Name, product);

    // Try multiple ways to get the price

    // 1. Check PricebookEntries with records array
    if (product?.PricebookEntries?.records?.length > 0) {
      const price = product.PricebookEntries.records[0].UnitPrice;
      console.log("Found price from PricebookEntries.records:", price);
      return price;
    }

    // 2. Check PricebookEntries as direct array (in case it's not wrapped in records)
    if (product?.PricebookEntries?.length > 0) {
      const price = product.PricebookEntries[0].UnitPrice;
      console.log("Found price from direct PricebookEntries array:", price);
      return price;
    }

    // 3. Check for any custom price field that might exist
    const possiblePriceFields = [
      "Price__c",
      "List_Price__c",
      "Unit_Price__c",
      "Cost__c",
      "MSRP__c",
      "Base_Price__c"
    ];
    for (const field of possiblePriceFields) {
      if (product[field] !== undefined && product[field] !== null) {
        console.log(`Found price from custom field ${field}:`, product[field]);
        return product[field];
      }
    }

    console.log("No price found for product:", product.Name);
    return 0; // Default price if not found
  }

  // Fetch prices for recommended products that don't have them
  fetchRecommendedProductPrices() {
    const productsNeedingPrices = this.recommendedProducts.filter(
      (p) => p.needsPriceFetch
    );
    console.log(
      "Fetching prices for recommended products:",
      productsNeedingPrices.map((p) => p.Name)
    );

    if (productsNeedingPrices.length === 0) {
      console.log("All recommended products already have prices");
      return;
    }

    const pricePromises = productsNeedingPrices.map((product) =>
      getProductPrice({ productId: product.Id })
        .then((price) => {
          console.log(`Fetched price for ${product.Name}: ${price}`);
          return { productId: product.Id, price: price || 0 };
        })
        .catch((error) => {
          console.error(
            `Error fetching price for recommended product ${product.Name}:`,
            error
          );
          return { productId: product.Id, price: 0 };
        })
    );

    Promise.all(pricePromises)
      .then((results) => {
        console.log("All recommended product prices fetched:", results);

        // Update recommended products with fetched prices
        this.recommendedProducts = this.recommendedProducts.map((product) => {
          const priceResult = results.find((r) => r.productId === product.Id);
          if (priceResult && priceResult.price > 0) {
            return {
              ...product,
              unitPrice: `${priceResult.price.toFixed(2)}`,
              needsPriceFetch: false
            };
          }
          return {
            ...product,
            unitPrice:
              product.unitPrice === "Loading price..."
                ? "Price not available"
                : product.unitPrice
          };
        });

        console.log(
          "Updated recommended products with prices:",
          this.recommendedProducts
        );
      })
      .catch((error) => {
        console.error("Error fetching recommended product prices:", error);
        // Update products to show "Price not available" instead of "Loading price..."
        this.recommendedProducts = this.recommendedProducts.map((product) => ({
          ...product,
          unitPrice:
            product.unitPrice === "Loading price..."
              ? "Price not available"
              : product.unitPrice
        }));
      });
  }

  // Handle removing a product from the selected products
  handleRemoveProduct(event) {
    console.log("=== REMOVE PRODUCT DEBUG ===");
    console.log("Event received:", event);
    console.log("Event target:", event.target);
    console.log("Event currentTarget:", event.currentTarget);

    // Try to get product ID from target or currentTarget
    let productIdToRemove =
      event.target.dataset.productId || event.currentTarget.dataset.productId;

    // If still no ID found, try parent elements (in case clicking on icon)
    if (!productIdToRemove && event.target.parentElement) {
      productIdToRemove = event.target.parentElement.dataset.productId;
    }

    console.log("Product ID to remove:", productIdToRemove);
    console.log("Target dataset:", event.target.dataset);
    console.log("CurrentTarget dataset:", event.currentTarget.dataset);

    if (!productIdToRemove) {
      console.error("No product ID found for removal");
      console.log(
        "Target available dataset keys:",
        Object.keys(event.target.dataset || {})
      );
      console.log(
        "CurrentTarget available dataset keys:",
        Object.keys(event.currentTarget.dataset || {})
      );
      return;
    }

    // Find the product being removed for logging
    const productToRemove = this.products.find(
      (p) => p.Id === productIdToRemove
    );
    console.log("Removing product:", productToRemove?.Name);

    // Remove from products array
    this.products = this.products.filter(
      (product) => product.Id !== productIdToRemove
    );

    // Remove from quantities and prices
    const updatedQuantities = { ...this.quantities };
    const updatedPrices = { ...this.productPrices };
    delete updatedQuantities[productIdToRemove];
    delete updatedPrices[productIdToRemove];

    this.quantities = updatedQuantities;
    this.productPrices = updatedPrices;

    // Update subtotals for remaining products
    this.updateProductSubtotals();

    // Save updated data
    this.saveProductDetailData();

    // Refresh recommendations since excluded products changed
    this.fetchRecommendedProducts();

    // Show toast message
    this.showToast(
      "Product Removed",
      `${productToRemove?.Name || "Product"} has been removed from your cart.`,
      "success"
    );

    console.log("Updated products after removal:", this.products.length);
  }

  // Handle quantity change for recommended products
  handleRecommendedQuantityChange(event) {
    const productId = event.target.dataset.productId;
    const quantity = parseInt(event.target.value, 10);

    if (!isNaN(quantity) && quantity > 0 && productId) {
      this.recommendedQuantities = {
        ...this.recommendedQuantities,
        [productId]: quantity
      };
      console.log("Updated recommended quantity:", productId, quantity);
    }
  }

  // Handle adding a recommended product to the main products list
  handleAddRecommendedProduct(event) {
    const productId = event.target.dataset.productId;
    console.log("Adding recommended product:", productId);

    if (!productId) {
      console.error("No product ID found for addition");
      return;
    }

    // Find the recommended product
    const recommendedProduct = this.recommendedProducts.find(
      (p) => p.Id === productId
    );
    if (!recommendedProduct) {
      console.error("Recommended product not found:", productId);
      return;
    }

    console.log("Adding recommended product:", recommendedProduct.Name);

    // Check if product is already in the cart
    const existingProduct = this.products.find((p) => p.Id === productId);
    if (existingProduct) {
      this.showToast(
        "Product Already Added",
        `${recommendedProduct.Name} is already in your cart.`,
        "warning"
      );
      return;
    }

    // Use default quantity of 1 for recommended products
    const quantity = 1;

    // Extract numeric price from the unitPrice string
    const unitPriceString = recommendedProduct.unitPrice;
    let unitPrice = 0;
    if (
      unitPriceString &&
      unitPriceString !== "Loading price..." &&
      unitPriceString !== "Price not available"
    ) {
      unitPrice = parseFloat(unitPriceString);
    }

    // Add to main products array
    const newProduct = {
      ...recommendedProduct,
      unitPrice: unitPrice.toFixed(2),
      subtotal: (unitPrice * quantity).toFixed(2)
    };

    this.products = [...this.products, newProduct];

    // Add to quantities and prices
    this.quantities = { ...this.quantities, [productId]: quantity };
    this.productPrices = { ...this.productPrices, [productId]: unitPrice };

    // Update subtotals
    this.updateProductSubtotals();

    // Save updated data
    this.saveProductDetailData();

    // Remove from recommended products list
    this.recommendedProducts = this.recommendedProducts.filter(
      (p) => p.Id !== productId
    );

    // Clean up recommended quantities
    const updatedRecommendedQuantities = { ...this.recommendedQuantities };
    delete updatedRecommendedQuantities[productId];
    this.recommendedQuantities = updatedRecommendedQuantities;

    // Show success message
    this.showToast(
      "Product Added",
      `${recommendedProduct.Name} (Qty: ${quantity}) has been added to your cart.`,
      "success"
    );

    console.log(
      "Product added successfully. Total products:",
      this.products.length
    );
    console.log("Updated totals:", {
      subtotal: this.totalPriceWithoutTax,
      tax: this.taxAmount,
      total: this.totalPriceWithTax
    });
  }

  get hasRecommendedProducts() {
    return this.recommendedProducts && this.recommendedProducts.length > 0;
  }

  // Dynamic messaging for no-recommendations state
  get noRecommendationsTitle() {
    // Check if all filters are explicitly set to None/empty (user selected "None")
    const allFiltersAreNone =
      this._selectedBillingType === "" &&
      this._selectedFamilyType === "" &&
      this._selectedStageType === "" &&
      this._selectedPreferredBlockType === "";

    if (allFiltersAreNone && this.hasUserModifiedFilters) {
      return "No filter criteria selected";
    } else if (this.hasUserModifiedFilters) {
      return "No products match your custom filters";
    } else {
      return "No matching products found";
    }
  }

  get noRecommendationsMessage() {
    // Check if all filters are explicitly set to None/empty (user selected "None")
    const allFiltersAreNone =
      this._selectedBillingType === "" &&
      this._selectedFamilyType === "" &&
      this._selectedStageType === "" &&
      this._selectedPreferredBlockType === "";

    if (allFiltersAreNone && this.hasUserModifiedFilters) {
      return 'You have set all filter criteria to "None". Please select at least one filter criteria to find matching products, or use the reset button to return to the default filter settings.';
    } else if (this.hasUserModifiedFilters) {
      return "Your current filter combination is too specific. Try adjusting or removing some filters to discover more products that complement your selection.";
    } else {
      return "Based on your selected products and filter criteria, we couldn't find matching recommendations. Try using the advanced filters to explore different product categories.";
    }
  }

  get hasActiveFiltersForMessage() {
    return this.activeFilters && this.activeFilters.length > 0;
  }

  // Wire methods for filter options
  @wire(getObjectInfo, { objectApiName: PRODUCT2_OBJECT })
  productObjectInfo;

  @wire(getPicklistValues, {
    recordTypeId: "$productObjectInfo.data.defaultRecordTypeId",
    fieldApiName: BILLING_TYPE_FIELD
  })
  wiredBillingPickList({ data, error }) {
    if (data) {
      this.billingTypeFilterOptions = data.values.map((v) => ({
        label: v.label,
        value: v.value,
        cssClass:
          this._selectedBillingType === v.value
            ? "filter-pill-button selected"
            : "filter-pill-button"
      }));
    } else if (error) {
      console.error("Billing picklist error:", error);
    }
  }

  @wire(getPicklistValues, {
    recordTypeId: "$productObjectInfo.data.defaultRecordTypeId",
    fieldApiName: Family_FIELD
  })
  wiredFamilyPickList({ data, error }) {
    if (data) {
      this.familyTypeFilterOptions = data.values.map((v) => ({
        label: v.label,
        value: v.value,
        cssClass:
          this._selectedFamilyType === v.value
            ? "filter-pill-button selected"
            : "filter-pill-button"
      }));
    } else if (error) {
      console.error("Family picklist error:", error);
    }
  }

  @wire(getPicklistValues, {
    recordTypeId: "$productObjectInfo.data.defaultRecordTypeId",
    fieldApiName: Stage__FIELD
  })
  wiredStagePickList({ data, error }) {
    if (data) {
      this.stageTypeFilterOptions = data.values.map((v) => ({
        label: v.label,
        value: v.value,
        cssClass:
          this._selectedStageType === v.value
            ? "filter-pill-button selected"
            : "filter-pill-button"
      }));
    } else if (error) {
      console.error("Stage picklist error:", error);
    }
  }

  @wire(getPicklistValues, {
    recordTypeId: "$productObjectInfo.data.defaultRecordTypeId",
    fieldApiName: Preferred_Block__FIELD
  })
  wiredPreferredBlockPickList({ data, error }) {
    if (data) {
      this.preferredBlockTypeFilterOptions = data.values.map((v) => ({
        label: v.label,
        value: v.value,
        cssClass:
          this._selectedPreferredBlockType === v.value
            ? "filter-pill-button selected"
            : "filter-pill-button"
      }));
    } else if (error) {
      console.error("Preferred block picklist error:", error);
    }
  }

  // Store original filter criteria when component loads
  storeOriginalFilters() {
    this.originalBillingType = this._selectedBillingType;
    this.originalFamilyType = this._selectedFamilyType;
    this.originalStageType = this._selectedStageType;
    this.originalPreferredBlockType = this._selectedPreferredBlockType;
  }

  // Filter change handlers
  handleFilterChange(event) {
    const filterType = event.target.dataset.filter;
    const selectedValue = event.detail.value;

    console.log("Slider filter changed by user:", filterType, selectedValue);

    // Mark that user has modified filters - now slider controls the filters
    this.hasUserModifiedFilters = true;

    // Update the appropriate filter
    switch (filterType) {
      case "billingType":
        this._selectedBillingType = selectedValue;
        break;
      case "familyType":
        this._selectedFamilyType = selectedValue;
        break;
      case "stageType":
        this._selectedStageType = selectedValue;
        break;
      case "preferredBlockType":
        this._selectedPreferredBlockType = selectedValue;
        break;
    }

    console.log("Filter value updated, waiting for Apply Filters button click");
  }

  // Handle pill button clicks for filters
  handleFilterPillClick(event) {
    const filterType = event.target.dataset.filter;
    const selectedValue = event.target.dataset.value;

    console.log("Filter pill clicked:", filterType, selectedValue);

    // Mark that user has modified filters
    this.hasUserModifiedFilters = true;

    // Check if the clicked value is already selected (for toggle functionality)
    let currentValue = "";
    let newValue = "";

    switch (filterType) {
      case "billingType":
        currentValue = this._selectedBillingType;
        newValue = currentValue === selectedValue ? "" : selectedValue;
        this._selectedBillingType = newValue;
        this.updateFilterPillCssClasses("billingTypeFilterOptions", newValue);
        break;
      case "familyType":
        currentValue = this._selectedFamilyType;
        newValue = currentValue === selectedValue ? "" : selectedValue;
        this._selectedFamilyType = newValue;
        this.updateFilterPillCssClasses("familyTypeFilterOptions", newValue);
        break;
      case "stageType":
        currentValue = this._selectedStageType;
        newValue = currentValue === selectedValue ? "" : selectedValue;
        this._selectedStageType = newValue;
        this.updateFilterPillCssClasses("stageTypeFilterOptions", newValue);
        break;
      case "preferredBlockType":
        currentValue = this._selectedPreferredBlockType;
        newValue = currentValue === selectedValue ? "" : selectedValue;
        this._selectedPreferredBlockType = newValue;
        this.updateFilterPillCssClasses(
          "preferredBlockTypeFilterOptions",
          newValue
        );
        break;
    }

    console.log(
      `${filterType} ${newValue ? "selected" : "deselected"}:`,
      newValue || "none"
    );
  }

  // Helper method to update CSS classes for filter pill options
  updateFilterPillCssClasses(optionsProperty, selectedValue) {
    if (this[optionsProperty]) {
      this[optionsProperty] = this[optionsProperty].map((option) => ({
        ...option,
        cssClass:
          option.value === selectedValue
            ? "filter-pill-button selected"
            : "filter-pill-button"
      }));
    }
  }

  // Reset filters to original values
  handleResetFilters() {
    console.log(
      "Resetting filters to original values (from filterCriteriaComponent)"
    );

    this._selectedBillingType = this.originalBillingType;
    this._selectedFamilyType = this.originalFamilyType;
    this._selectedStageType = this.originalStageType;
    this._selectedPreferredBlockType = this.originalPreferredBlockType;

    // Reset the user modification flag - now back to using filterCriteriaComponent filters
    this.hasUserModifiedFilters = false;

    // Reset slider position
    this.currentSlideIndex = 0;

    // Fetch recommendations with original filters from filterCriteriaComponent
    this.fetchRecommendedProducts();

    this.showToast(
      "Filters Reset",
      "Filters have been reset to original criteria from Filter Component.",
      "info"
    );

    // Close the filter panel (same as Apply Filters)
    this.showAdvancedFilters = false;

    console.log(
      "Filters reset. Recommendations will now be based on filterCriteriaComponent again."
    );
  }

  // Slider functionality
  get sliderTransform() {
    if (!this.hasRecommendedProducts) {
      return "transform: translateX(0px)";
    }

    // Calculate based on fixed item width + gap
    const itemWidth = 280; // Fixed width from CSS
    const gap = 16; // 1rem = 16px gap
    const slideWidth = (itemWidth + gap) * this.itemsPerSlide;
    const translateX = -(this.currentSlideIndex * slideWidth);
    const transform = `transform: translateX(${translateX}px)`;

    console.log("Slider transform:", {
      currentSlideIndex: this.currentSlideIndex,
      itemsPerSlide: this.itemsPerSlide,
      itemWidth,
      gap,
      slideWidth,
      translateX,
      transform
    });

    return transform;
  }

  get isFirstSlide() {
    return this.currentSlideIndex === 0;
  }

  get isLastSlide() {
    const totalProducts = this.recommendedProducts.length;
    const maxSlideIndex = Math.max(
      0,
      Math.ceil(totalProducts / this.itemsPerSlide) - 1
    );
    return this.currentSlideIndex >= maxSlideIndex;
  }

  get showSliderIndicators() {
    return this.recommendedProducts.length > this.itemsPerSlide;
  }

  get totalRecommendations() {
    return this.recommendedProducts.length;
  }

  get currentSlideStart() {
    return this.currentSlideIndex * this.itemsPerSlide + 1;
  }

  get currentSlideEnd() {
    const end = (this.currentSlideIndex + 1) * this.itemsPerSlide;
    return Math.min(end, this.totalRecommendations);
  }

  // Initialize slider when products are loaded
  initializeSlider() {
    // Reset slider position
    this.currentSlideIndex = 0;

    // Set responsive items per slide
    this.setResponsiveItemsPerSlide();

    // Update indicators
    this.updateSliderIndicators();

    // Start auto-play if enabled and we have multiple slides
    if (
      this.isAutoPlaying &&
      this.recommendedProducts.length > this.itemsPerSlide
    ) {
      setTimeout(() => {
        this.startAutoPlay();
      }, 500); // Small delay to ensure DOM is ready
    }

    console.log("Slider initialized:", {
      currentSlideIndex: this.currentSlideIndex,
      itemsPerSlide: this.itemsPerSlide,
      totalProducts: this.recommendedProducts.length,
      indicators: this.sliderIndicators.length,
      autoPlayStarted:
        this.isAutoPlaying &&
        this.recommendedProducts.length > this.itemsPerSlide
    });
  }

  // Update slider indicators whenever products change
  updateSliderIndicators() {
    const totalProducts = this.recommendedProducts.length;
    const totalSlides = Math.ceil(totalProducts / this.itemsPerSlide);

    this.sliderIndicators = [];
    for (let i = 0; i < totalSlides; i++) {
      this.sliderIndicators.push({
        index: i,
        cssClass:
          i === this.currentSlideIndex
            ? "slider-indicator active"
            : "slider-indicator",
        title: `Page ${i + 1} of ${totalSlides}`
      });
    }

    // Slider indicators updated
  }

  // Debug method to manually refresh slider
  @api
  refreshSlider() {
    console.log("Manually refreshing slider...");
    this.initializeSlider();

    // Force re-render by updating a tracked property
    this.currentSlideIndex = this.currentSlideIndex;
  }

  // Debug method to manually start auto-play
  @api
  debugStartAutoPlay() {
    console.log("Debug: Manually starting auto-play...");
    this.isAutoPlaying = true;
    this.startAutoPlay();
  }

  handleSliderPrevious() {
    if (!this.isFirstSlide) {
      this.currentSlideIndex -= 1;
      this.updateSliderIndicators();
    }
  }

  handleSliderNext() {
    if (!this.isLastSlide) {
      this.currentSlideIndex += 1;
      this.updateSliderIndicators();
    }
  }

  handleSliderIndicatorClick(event) {
    const slideIndex = parseInt(event.target.dataset.slide);
    if (!isNaN(slideIndex)) {
      this.currentSlideIndex = slideIndex;
      this.updateSliderIndicators();
    }
  }

  // Override fetchRecommendedProducts to update slider indicators
  fetchRecommendedProducts() {
    console.log("fetchRecommendedProducts called with:", {
      billingType: this._selectedBillingType,
      familyType: this._selectedFamilyType,
      stageType: this._selectedStageType,
      preferredBlockType: this._selectedPreferredBlockType
    });

    // Check if all filters are explicitly set to empty/None values
    const allFiltersAreNone =
      this._selectedBillingType === "" &&
      this._selectedFamilyType === "" &&
      this._selectedStageType === "" &&
      this._selectedPreferredBlockType === "";

    // Check if no filters are set at all (initial state)
    const noFiltersSet =
      !this._selectedBillingType &&
      !this._selectedFamilyType &&
      !this._selectedStageType &&
      !this._selectedPreferredBlockType;

    // If all filters are explicitly set to None/empty, clear recommendations and show message
    if (allFiltersAreNone) {
      console.log("All filters set to None - clearing recommendations");
      this.recommendedProducts = [];
      this.updateSliderIndicators();
      return;
    }

    // If no filters are set and user hasn't modified filters, skip (initial state)
    if (noFiltersSet && !this.hasUserModifiedFilters) {
      console.log(
        "No filter criteria set and user has not modified filters, skipping recommendation fetch"
      );
      return;
    }

    console.log("Excluded product IDs:", this.excludedProductIds);

    getRecommendedProducts({
      billingType: this._selectedBillingType || "",
      familyType: this._selectedFamilyType || "",
      stageType: this._selectedStageType || "",
      preferredBlockType: this._selectedPreferredBlockType || "",
      excludedProductIds: this.excludedProductIds
    })
      .then((data) => {
        console.log("Raw recommended products data:", data);

        // Process products and handle price fetching
        const processedProducts = data.map((p) => {
          const price = this.extractProductPrice(p);
          return {
            ...p,
            imageUrl: this.getImageUrl(p?.Product_Image__c),
            unitPrice: price ? `${price.toFixed(2)}` : "Loading price...",
            needsPriceFetch: price === 0 // Flag products that need price fetching
          };
        });

        this.recommendedProducts = processedProducts;
        console.log(
          "Initial processed recommended products:",
          this.recommendedProducts
        );

        // Update slider indicators after products are loaded
        this.updateSliderIndicators();

        // Fetch prices for products that don't have them
        this.fetchRecommendedProductPrices();

        console.log("hasRecommendedProducts:", this.hasRecommendedProducts);
      })
      .catch((error) => {
        console.error(
          "Error fetching recommended products:",
          JSON.stringify(error)
        );
        if (error && error.body && error.body.message) {
          console.error("Apex Error Message:", error.body.message);
        }
        // Set empty array on error to show no-recommendations message
        this.recommendedProducts = [];
        this.updateSliderIndicators();
      });
  }

  // Override processSelectedProducts to store original filters
  processSelectedProducts() {
    if (
      this.selectedProducts &&
      Array.isArray(this.selectedProducts) &&
      this.selectedProducts.length > 0
    ) {
      this.products = this.selectedProducts.map((p) => {
        return {
          ...p,
          imageUrl: this.getImageUrl(p?.Product_Image__c),
          unitPrice: "0.00" // Will be updated when prices are fetched
        };
      });

      // Save products for persistence
      this.saveProductDetailData();

      // Fetch prices for ALL products
      if (this.products.length > 0) {
        this.fetchAllProductPrices();
        // Set filter criteria for recommendations from the first selected product
        const firstProduct = this.products[0];
        if (firstProduct) {
          this.selectedBillingType = firstProduct.Billing_Type__c;
          this.selectedFamilyType = firstProduct.Family;
          this.selectedStageType = firstProduct.Stage__c;
          this.selectedPreferredBlockType = firstProduct.Preferred_Block__c;

          // Store original filter values for reset functionality
          this.storeOriginalFilters();
        }
      }
    } else {
      // Try to load from storage if no products from parent
      this.loadProductDetailData();
    }

    // Load saved form data (but don't override if we have a term from parent)
    this.loadFormData();

    console.log("Final selectedProductTerm value:", this.selectedProductTerm);
  }

  // ===== ENHANCED SLIDER FUNCTIONALITY =====

  // Auto-play functionality
  handleToggleAutoPlay() {
    this.isAutoPlaying = !this.isAutoPlaying;

    if (this.isAutoPlaying) {
      this.startAutoPlay();
      this.showToast(
        "Auto-play Started",
        "Recommendations will advance automatically",
        "info"
      );
    } else {
      this.stopAutoPlay();
      this.showToast("Auto-play Stopped", "Manual control restored", "info");
    }
  }

  startAutoPlay() {
    console.log("Starting auto-play...", {
      hasRecommendedProducts: this.hasRecommendedProducts,
      totalProducts: this.recommendedProducts.length,
      itemsPerSlide: this.itemsPerSlide,
      isAutoPlaying: this.isAutoPlaying,
      currentSlideIndex: this.currentSlideIndex,
      isLastSlide: this.isLastSlide
    });

    if (this.autoPlayInterval) {
      clearInterval(this.autoPlayInterval);
    }

    // Only start auto-play if we have more products than can fit in one slide
    if (this.recommendedProducts.length <= this.itemsPerSlide) {
      console.log("Not enough products for auto-play");
      return;
    }

    this.autoPlayInterval = setInterval(() => {
      console.log("Auto-play tick:", {
        currentSlideIndex: this.currentSlideIndex,
        isLastSlide: this.isLastSlide
      });

      if (!this.isLastSlide) {
        this.currentSlideIndex += 1;
      } else {
        this.currentSlideIndex = 0; // Loop back to first slide
      }
      this.updateSliderIndicators();
    }, 3000); // Change slide every 3 seconds

    console.log("Auto-play started with interval:", this.autoPlayInterval);
  }

  stopAutoPlay() {
    if (this.autoPlayInterval) {
      clearInterval(this.autoPlayInterval);
      this.autoPlayInterval = null;
    }
  }

  disconnectedCallback() {
    // Clean up auto-play when component is destroyed
    this.stopAutoPlay();
    if (this.debounceTimeout) {
      clearTimeout(this.debounceTimeout);
    }
  }

  // Touch/swipe support
  handleTouchStart(event) {
    this.touchStartX = event.touches[0].clientX;
    // Pause auto-play during user interaction
    if (this.isAutoPlaying) {
      this.stopAutoPlay();
    }
  }

  handleTouchMove(event) {
    event.preventDefault(); // Prevent scrolling
  }

  handleTouchEnd(event) {
    this.touchEndX = event.changedTouches[0].clientX;
    this.handleSwipe();

    // Resume auto-play if it was active
    if (this.isAutoPlaying) {
      setTimeout(() => {
        this.startAutoPlay();
      }, 1000); // Resume after 1 second
    }
  }

  handleSwipe() {
    const swipeThreshold = 50; // Minimum distance for a swipe
    const swipeDistance = this.touchStartX - this.touchEndX;

    if (Math.abs(swipeDistance) > swipeThreshold) {
      if (swipeDistance > 0 && !this.isLastSlide) {
        // Swipe left - next slide
        this.handleSliderNext();
      } else if (swipeDistance < 0 && !this.isFirstSlide) {
        // Swipe right - previous slide
        this.handleSliderPrevious();
      }
    }
  }

  // Enhanced computed properties
  get autoPlayIcon() {
    return this.isAutoPlaying ? "utility:pause" : "utility:play";
  }

  get autoPlayTitle() {
    return this.isAutoPlaying ? "Pause auto-play" : "Start auto-play";
  }

  get filtersContainerClass() {
    return `filters-container ${this.showAdvancedFilters ? "expanded" : ""}`;
  }

  get filtersToggleIcon() {
    return this.showAdvancedFilters
      ? "utility:chevronup"
      : "utility:chevrondown";
  }

  // ===== ADVANCED FILTERING =====

  // Search functionality with debouncing
  handleSearchChange(event) {
    const searchValue = event.target.value;

    // Clear existing timeout
    if (this.debounceTimeout) {
      clearTimeout(this.debounceTimeout);
    }

    // Set new timeout for debounced search
    this.debounceTimeout = setTimeout(() => {
      this.searchTerm = searchValue;
      this.applyFiltersAndSearch();
    }, 300); // 300ms delay
  }

  applyFiltersAndSearch() {
    let filtered = [...this.recommendedProducts];

    // Apply search filter
    if (this.searchTerm && this.searchTerm.trim() !== "") {
      const searchLower = this.searchTerm.toLowerCase();
      filtered = filtered.filter(
        (product) =>
          product.Name.toLowerCase().includes(searchLower) ||
          (product.Description &&
            product.Description.toLowerCase().includes(searchLower)) ||
          (product.Family &&
            product.Family.toLowerCase().includes(searchLower)) ||
          (product.Billing_Type__c &&
            product.Billing_Type__c.toLowerCase().includes(searchLower))
      );
    }

    this.filteredRecommendedProducts = filtered;
    this.updateActiveFilters();

    // Reset slider to first page
    this.currentSlideIndex = 0;
    this.updateSliderIndicators();
  }

  updateActiveFilters() {
    const filters = [];

    if (this._selectedBillingType) {
      filters.push({
        key: "billingType",
        label: `Billing: ${this._selectedBillingType}`,
        type: "billingType",
        value: this._selectedBillingType
      });
    }

    if (this._selectedFamilyType) {
      filters.push({
        key: "familyType",
        label: `Family: ${this._selectedFamilyType}`,
        type: "familyType",
        value: this._selectedFamilyType
      });
    }

    if (this._selectedStageType) {
      filters.push({
        key: "stageType",
        label: `Stage: ${this._selectedStageType}`,
        type: "stageType",
        value: this._selectedStageType
      });
    }

    if (this._selectedPreferredBlockType) {
      filters.push({
        key: "preferredBlockType",
        label: `Block: ${this._selectedPreferredBlockType}`,
        type: "preferredBlockType",
        value: this._selectedPreferredBlockType
      });
    }

    if (this.searchTerm && this.searchTerm.trim() !== "") {
      filters.push({
        key: "search",
        label: `Search: "${this.searchTerm}"`,
        type: "search",
        value: this.searchTerm
      });
    }

    this.activeFilters = filters;
  }

  // Filter management
  handleToggleFilters() {
    this.showAdvancedFilters = !this.showAdvancedFilters;
  }

  handleRemoveFilter(event) {
    const filterKey = event.target.dataset.filterKey;

    switch (filterKey) {
      case "billingType":
        this._selectedBillingType = "";
        break;
      case "familyType":
        this._selectedFamilyType = "";
        break;
      case "stageType":
        this._selectedStageType = "";
        break;
      case "preferredBlockType":
        this._selectedPreferredBlockType = "";
        break;
      case "search":
        this.searchTerm = "";
        // Clear the search input
        const searchInput = this.template.querySelector(".product-search");
        if (searchInput) {
          searchInput.value = "";
        }
        break;
    }

    this.fetchRecommendedProducts();
    this.applyFiltersAndSearch();
  }

  handleClearAllFilters() {
    this._selectedBillingType = "";
    this._selectedFamilyType = "";
    this._selectedStageType = "";
    this._selectedPreferredBlockType = "";
    this.searchTerm = "";

    // Clear the search input
    const searchInput = this.template.querySelector(".product-search");
    if (searchInput) {
      searchInput.value = "";
    }

    this.fetchRecommendedProducts();
    this.applyFiltersAndSearch();
    this.showToast(
      "All Filters Cleared",
      "Showing all available recommendations",
      "info"
    );
  }

  handleApplyFilters() {
    console.log("Applying filters:", {
      billingType: this._selectedBillingType,
      familyType: this._selectedFamilyType,
      stageType: this._selectedStageType,
      preferredBlockType: this._selectedPreferredBlockType
    });

    // Reset slider position when filters are applied
    this.currentSlideIndex = 0;

    // Fetch new recommendations based on current filter values
    this.fetchRecommendedProducts();

    this.showToast(
      "Filters Applied",
      "Recommendations updated with current filters",
      "success"
    );

    // Optionally collapse the filter panel
    this.showAdvancedFilters = false;
  }

  // View management
  handleToggleViewAll() {
    this.viewAllMode = !this.viewAllMode;

    if (this.viewAllMode) {
      // Stop auto-play in view all mode
      this.stopAutoPlay();
      this.isAutoPlaying = false;
      this.showToast(
        "View All Mode",
        "Showing all recommendations in grid view",
        "info"
      );
    } else {
      this.showToast("Slider Mode", "Back to slider view", "info");
    }
  }

  // Quick view functionality (placeholder)
  handleQuickView(event) {
    const productId = event.target.dataset.productId;
    const product = this.recommendedProducts.find((p) => p.Id === productId);

    if (product) {
      // This could open a modal or navigate to product detail
      this.showToast(
        "Quick View",
        `Viewing details for ${product.Name}`,
        "info"
      );

      // In a real implementation, you might:
      // 1. Open a modal with product details
      // 2. Navigate to product detail page
      // 3. Show expanded product information
    }
  }

  // Enhanced slider with keyboard support
  @api
  handleKeyDown(event) {
    if (!this.hasRecommendedProducts) return;

    switch (event.key) {
      case "ArrowLeft":
        event.preventDefault();
        this.handleSliderPrevious();
        break;
      case "ArrowRight":
        event.preventDefault();
        this.handleSliderNext();
        break;
      case " ": // Spacebar
        event.preventDefault();
        this.handleToggleAutoPlay();
        break;
    }
  }

  // Responsive slider items per slide
  renderedCallback() {
    if (this.hasRendered) return;
    this.hasRendered = true;

    // Set responsive items per slide based on screen size
    this.setResponsiveItemsPerSlide();

    // Add resize listener for responsive behavior
    window.addEventListener("resize", this.handleResize.bind(this));

    // Start autoplay automatically if we have recommended products
    // Use a small delay to ensure the DOM is fully rendered
    setTimeout(() => {
      if (this.hasRecommendedProducts && this.isAutoPlaying) {
        this.startAutoPlay();
      }
    }, 200);
  }

  handleResize() {
    // Debounce resize events
    clearTimeout(this.resizeTimeout);
    this.resizeTimeout = setTimeout(() => {
      this.setResponsiveItemsPerSlide();
      this.updateSliderIndicators();
    }, 250);
  }

  setResponsiveItemsPerSlide() {
    const container = this.template.querySelector(".slider-wrapper");
    let containerWidth = window.innerWidth; // Fallback to window width

    if (container && container.offsetWidth > 0) {
      containerWidth = container.offsetWidth;
    }

    if (containerWidth < 768) {
      this.itemsPerSlide = 1; // Mobile: 1 item
    } else if (containerWidth < 1200) {
      this.itemsPerSlide = 2; // Tablet: 2 items
    } else {
      this.itemsPerSlide = 3; // Desktop: 3 items
    }

    // Reset slide index if it's out of bounds
    const maxSlideIndex = Math.max(
      0,
      Math.ceil(this.totalRecommendations / this.itemsPerSlide) - 1
    );
    if (this.currentSlideIndex > maxSlideIndex) {
      this.currentSlideIndex = maxSlideIndex;
    }

    console.log("Responsive items per slide set:", {
      containerWidth,
      itemsPerSlide: this.itemsPerSlide,
      currentSlideIndex: this.currentSlideIndex,
      maxSlideIndex
    });
  }

  // Enhanced error handling for recommendations
  handleRecommendationError(error) {
    console.error("Recommendation error:", error);

    let errorMessage = "Failed to load recommendations";

    if (error?.body?.message) {
      errorMessage = error.body.message;
    } else if (error?.message) {
      errorMessage = error.message;
    }

    this.showToast("Error", errorMessage, "error");

    // Set empty state
    this.recommendedProducts = [];
    this.updateActiveFilters();
  }

  // Performance optimization: lazy loading for images
  handleImageLoad(event) {
    const img = event.target;
    img.style.opacity = "1";
    img.style.transition = "opacity 0.3s ease";
  }

  handleImageError(event) {
    const img = event.target;
    const placeholder = img.parentElement.querySelector(
      ".no-image-placeholder"
    );
    if (placeholder) {
      img.style.display = "none";
      placeholder.style.display = "flex";
    }
  }

  // Analytics/tracking methods (placeholders)
  trackSliderInteraction(action, productId = null) {
    // Placeholder for analytics tracking
    console.log("Slider interaction:", {
      action,
      productId,
      slideIndex: this.currentSlideIndex
    });
  }

  trackFilterUsage(filterType, filterValue) {
    // Placeholder for filter usage tracking
    console.log("Filter used:", { filterType, filterValue });
  }

  // Enhanced product enhancement with ratings, badges etc.
  enhanceProductData(products) {
    return products.map((product) => {
      // Add computed properties for UI enhancement
      const enhanced = {
        ...product,
        isPopular: this.isPopularProduct(product),
        isNew: this.isNewProduct(product),
        rating: this.getProductRating(product),
        reviewCount: this.getReviewCount(product)
      };

      return enhanced;
    });
  }

  isPopularProduct(product) {
    // Logic to determine if product is popular
    // This could be based on sales data, view count, etc.
    return Math.random() > 0.7; // Placeholder logic
  }

  isNewProduct(product) {
    // Logic to determine if product is new
    if (product.CreatedDate) {
      const createdDate = new Date(product.CreatedDate);
      const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
      return createdDate > thirtyDaysAgo;
    }
    return false;
  }

  getProductRating(product) {
    // Placeholder for product rating logic
    return Math.floor(Math.random() * 5) + 1;
  }

  getReviewCount(product) {
    // Placeholder for review count logic
    return Math.floor(Math.random() * 100) + 1;
  }
}
