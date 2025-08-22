import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import { LightningElement, wire, track, api } from "lwc";
import PRODUCT2_OBJECT from "@salesforce/schema/Product2";
import ORDERLINE_OBECJT from "@salesforce/schema/OrderItem";
import BILLING_TYPE_FIELD from "@salesforce/schema/Product2.Billing_Type__c";
import Installation_Type_FIELD from "@salesforce/schema/Product2.Installation_Type__c";
import Family_FIELD from "@salesforce/schema/Product2.Family";
import Stage__FIELD from "@salesforce/schema/Product2.Stage__c";
import Preferred_Block__FIELD from "@salesforce/schema/Product2.Preferred_Block__c";
import Product_Terms__FIELD from "@salesforce/schema/OrderItem.Product_Terms__c";
import { NavigationMixin } from "lightning/navigation";
import getFilterProducts from "@salesforce/apex/FilterProductsHelper.getFilterProducts";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class FilterCriteriaComponent extends NavigationMixin(
  LightningElement
) {
  // Accept zipCode from parent
  @api zipCode;

  // Current view management
  @track currentView = "filter"; // 'filter', 'table', 'terms', 'detail', 'user-detail'
  @track filteredProductsData = [];
  @track selectedProductsData = [];

  // Product Terms related properties
  @track selectedMainOption = "";
  @track selectedProductTerm = "";
  @track selectedProductTotalPrice = 0;

  // Salesforce picklist data
  billingPicklistOptions;
  installationPicklistOptions;
  familyPicklistOptions;
  stagePicklistOptions;
  preferredBlockPicklistOptions;
  productTermPicklistOptions;

  // Selected values for Salesforce fields
  @track selectedBillingType = "";
  @track selectedInstallationType = "";
  @track selectedFamilyType = "";
  @track selectedStageType = "";
  @track selectedPreferredBlockType = "";
  @track selectedProductTermType = "";

  // Component initialization - only handle refresh detection
  connectedCallback() {
    // Check if this is a fresh session/refresh
    if (this.isFreshSession()) {
      this.clearAllStoredData();
      this.markSessionActive();
    }
  }

  clearAllStoredData() {
    localStorage.removeItem("filterCriteriaValues");
    localStorage.removeItem("filteredProductsData");
    localStorage.removeItem("selectedProductIds");
    localStorage.removeItem("productDetailFormData");
    localStorage.removeItem("productDetailData");
    localStorage.removeItem("navigationState");
    localStorage.removeItem("selectedProductsData");
  }

  markSessionActive() {
    sessionStorage.setItem("sessionActive", "true");
  }

  isFreshSession() {
    return !sessionStorage.getItem("sessionActive");
  }

  // Save current navigation state
  saveNavigationState() {
    const navigationState = {
      currentView: this.currentView,
      filteredProductsData: this.filteredProductsData,
      formAnswers: {
        selectedHomeType: this.selectedHomeType,
        selectedOwnershipType: this.selectedOwnershipType,
        selectedWaterType: this.selectedWaterType,
        selectedDrinkingWaterSource: this.selectedDrinkingWaterSource
      }
    };
    localStorage.setItem("navigationState", JSON.stringify(navigationState));
  }

  // Load saved navigation state
  loadNavigationState() {
    try {
      const savedState = localStorage.getItem("navigationState");
      if (savedState) {
        const state = JSON.parse(savedState);
        this.filteredProductsData = state.filteredProductsData || [];
        // Restore form answers
        if (state.formAnswers) {
          this.selectedHomeType = state.formAnswers.selectedHomeType || "";
          this.selectedOwnershipType =
            state.formAnswers.selectedOwnershipType || "";
          this.selectedWaterType = state.formAnswers.selectedWaterType || "";
          this.selectedDrinkingWaterSource =
            state.formAnswers.selectedDrinkingWaterSource || "";
        }
      }
    } catch (error) {
      console.error("Error loading navigation state:", error);
    }
  }

  // Save selected products data
  saveSelectedProducts(data) {
    try {
      // Use setTimeout to make localStorage operations non-blocking
      setTimeout(() => {
        if (data && Array.isArray(data)) {
          // Limit the size of data being saved to prevent performance issues
          if (data.length > 100) {
            console.warn(
              "Large dataset detected. Consider pagination for better performance."
            );
          }
          localStorage.setItem("selectedProductsData", JSON.stringify(data));
        } else {
          console.warn("Invalid data passed to saveSelectedProducts:", data);
        }
      }, 0);
    } catch (error) {
      console.error("Error saving selected products:", error);
      // Clear localStorage if quota exceeded
      if (error.name === "QuotaExceededError") {
        console.warn("localStorage quota exceeded. Clearing old data.");
        this.clearAllStoredData();
      }
    }
  }

  // Load selected products data
  loadSelectedProducts() {
    try {
      const savedProducts = localStorage.getItem("selectedProductsData");
      if (savedProducts) {
        this.selectedProductsData = JSON.parse(savedProducts);
      }
    } catch (error) {
      console.error("Error loading selected products:", error);
    }
  }

  // Force table component to reload selections
  forceTableSelectionReload() {
    // Use setTimeout to ensure the table component is rendered before calling the method
    setTimeout(() => {
      const tableComponent = this.template.querySelector(
        "c-filter-product-table-component"
      );
      if (tableComponent && tableComponent.reloadSelections) {
        tableComponent.reloadSelections();
      }
    }, 100);
  }

  // Wire services for Salesforce object info and picklist values
  @wire(getObjectInfo, { objectApiName: PRODUCT2_OBJECT })
  productObjectInfo;

  @wire(getObjectInfo, { objectApiName: ORDERLINE_OBECJT })
  OrderItemObjectInfo;

  // ------------- billing type -------------
  @wire(getPicklistValues, {
    recordTypeId: "$productObjectInfo.data.defaultRecordTypeId",
    fieldApiName: BILLING_TYPE_FIELD
  })
  wiredBillingPickList({ data, error }) {
    if (data) {
      this.billingPicklistOptions = data.values.map((v) => ({
        label: v.label,
        value: v.value,
        cssClass:
          this.selectedBillingType === v.value
            ? "pill-button selected"
            : "pill-button"
      }));
    } else if (error) {
      console.error("billing picklist error", error);
    }
  }

  // ------------- installation type -------------
  @wire(getPicklistValues, {
    recordTypeId: "$productObjectInfo.data.defaultRecordTypeId",
    fieldApiName: Installation_Type_FIELD
  })
  wiredInstallationPickList({ data, error }) {
    if (data) {
      this.installationPicklistOptions = data.values.map((v) => ({
        label: v.label,
        value: v.value
      }));
    } else if (error) {
      console.error("installation picklist error", error);
    }
  }

  // ------------- family -------------
  @wire(getPicklistValues, {
    recordTypeId: "$productObjectInfo.data.defaultRecordTypeId",
    fieldApiName: Family_FIELD
  })
  wiredFamilyPickList({ data, error }) {
    if (data) {
      this.familyPicklistOptions = data.values.map((v) => ({
        label: v.label,
        value: v.value,
        cssClass:
          this.selectedFamilyType === v.value
            ? "pill-button selected"
            : "pill-button"
      }));
    } else if (error) {
      console.error("family picklist error", error);
    }
  }

  // ------------- stage -------------
  @wire(getPicklistValues, {
    recordTypeId: "$productObjectInfo.data.defaultRecordTypeId",
    fieldApiName: Stage__FIELD
  })
  wiredStagePickList({ data, error }) {
    if (data) {
      this.stagePicklistOptions = data.values.map((v) => ({
        label: v.label,
        value: v.value,
        cssClass:
          this.selectedStageType === v.value
            ? "pill-button selected"
            : "pill-button"
      }));
    } else if (error) {
      console.error("stage picklist error", error);
    }
  }

  // ------------- preferred block -------------
  @wire(getPicklistValues, {
    recordTypeId: "$productObjectInfo.data.defaultRecordTypeId",
    fieldApiName: Preferred_Block__FIELD
  })
  wiredPreferredBlockPickList({ data, error }) {
    if (data) {
      this.preferredBlockPicklistOptions = data.values.map((v) => ({
        label: v.label,
        value: v.value,
        cssClass:
          this.selectedPreferredBlockType === v.value
            ? "pill-button selected"
            : "pill-button"
      }));
    } else if (error) {
      console.error("preferred block picklist error", error);
    }
  }

  // ------------- product terms -------------
  @wire(getPicklistValues, {
    recordTypeId: "012000000000000AAA",
    fieldApiName: Product_Terms__FIELD
  })
  wiredProductTermPickList({ data, error }) {
    if (data) {
      this.productTermPicklistOptions = data.values.map((v) => ({
        label: v.label,
        value: v.value
      }));
    } else if (error) {
      console.error("product term picklist error", error);
    }
  }

  // Unified picklist handler for Salesforce fields with toggle functionality
  handlePicklistChange(event) {
    const selectedValue = event.currentTarget.dataset.value;
    const fieldType = event.currentTarget.dataset.field;

    // Check if the clicked value is already selected (for toggle functionality)
    let currentValue = "";
    let newValue = "";

    switch (fieldType) {
      case "billingType":
        currentValue = this.selectedBillingType;
        // Toggle: if same value clicked, deselect it; otherwise select it
        newValue = currentValue === selectedValue ? "" : selectedValue;
        this.selectedBillingType = newValue;
        this.updatePicklistCssClasses("billingPicklistOptions", newValue);
        break;
      case "familyType":
        currentValue = this.selectedFamilyType;
        newValue = currentValue === selectedValue ? "" : selectedValue;
        this.selectedFamilyType = newValue;
        this.updatePicklistCssClasses("familyPicklistOptions", newValue);
        break;
      case "stageType":
        currentValue = this.selectedStageType;
        newValue = currentValue === selectedValue ? "" : selectedValue;
        this.selectedStageType = newValue;
        this.updatePicklistCssClasses("stagePicklistOptions", newValue);
        break;
      case "preferredBlockType":
        currentValue = this.selectedPreferredBlockType;
        newValue = currentValue === selectedValue ? "" : selectedValue;
        this.selectedPreferredBlockType = newValue;
        this.updatePicklistCssClasses(
          "preferredBlockPicklistOptions",
          newValue
        );
        break;
    }

    console.log(
      `${fieldType} ${newValue ? "selected" : "deselected"}:`,
      newValue || "none"
    );
  }

  // Helper method to update CSS classes for picklist options
  updatePicklistCssClasses(optionsProperty, selectedValue) {
    if (this[optionsProperty]) {
      this[optionsProperty] = this[optionsProperty].map((option) => ({
        ...option,
        cssClass:
          option.value === selectedValue
            ? "pill-button selected"
            : "pill-button"
      }));
    }
  }

  // Navigation methods
  handleBackToZip() {
    // Go back to zip code component
    const backEvent = new CustomEvent("back");
    this.dispatchEvent(backEvent);
  }

  handleFindProducts() {
    // Convert form answers to filter criteria for the backend
    const filterCriteria = this.mapAnswersToFilterCriteria();

    getFilterProducts(filterCriteria)
      .then((result) => {
        console.log("Filter results received:", result.length, "products");
        this.filteredProductsData = result;
        // Clear any existing selections when new filter is applied
        localStorage.removeItem("selectedProductIds");
        localStorage.removeItem("selectedProductsData");
        this.currentView = "table";
      })
      .catch((error) => {
        console.error("Error fetching products:", error);
        this.showToast(
          "Error",
          "Unable to load products. Please try again.",
          "error"
        );
      });
  }

  // Map form answers to backend filter criteria (using your existing backend parameter names)
  mapAnswersToFilterCriteria() {
    return {
      billingType: this.selectedBillingType,
      familyType: this.selectedFamilyType,
      stageType: this.selectedStageType,
      preferredBlockType: this.selectedPreferredBlockType
    };
  }

  // Handle navigation from child components
  handleNavigation(event) {
    const { view, data, preserveSelections, selectedTerms } = event.detail;

    console.log("handleNavigation called with:", {
      view,
      data: data ? data.length + " items" : "no data",
      preserveSelections,
      selectedTerms
    });
    console.log("Current view before navigation:", this.currentView);

    // Save current state before navigation
    this.saveNavigationState();

    // Set new view
    this.currentView = view;
    console.log("Current view after navigation:", this.currentView);

    // Handle data updates based on navigation
    if (view === "terms" && data) {
      this.selectedProductsData = data;
      // Calculate total price for selected products
      this.calculateSelectedProductsTotalPrice();
      // Save selected products to localStorage for persistence
      this.saveSelectedProducts(data);
    }

    if (view === "detail" && data) {
      this.selectedProductsData = data;
      // Save selected products to localStorage for persistence
      this.saveSelectedProducts(data);
    }

    // Handle navigation from ProductTermComponent with selected terms
    if (view === "detail" && selectedTerms) {
      // Load selected products from storage
      this.loadSelectedProducts();

      // Store the selected payment terms
      this.selectedMainOption = selectedTerms.mainOption;
      this.selectedProductTerm = selectedTerms.productTerm;

      console.log("Navigating to detail with selected terms:", selectedTerms);

      // Force component refresh by updating selectedProductsData
      this.selectedProductsData = [...this.selectedProductsData];
    }

    // Handle updated product data with quantities and prices for user-detail view
    if (view === "user-detail" && data) {
      this.selectedProductsData = data; // Update with quantity and price data
      // Save enhanced product data with quantities and prices
      this.saveSelectedProducts(data);
    }

    // When navigating back to table, restore filtered products
    if (view === "table") {
      this.loadNavigationState();

      // If preserveSelections flag is set, ensure selections are maintained
      if (preserveSelections) {
        // Force the table component to reload selections from localStorage
        this.forceTableSelectionReload();
      }
    }

    // When navigating back to terms, restore selected products
    if (view === "terms" && !data) {
      this.loadSelectedProducts();
      this.calculateSelectedProductsTotalPrice();
    }

    // When navigating back to detail, restore selected products
    if (view === "detail" && !data && !selectedTerms) {
      this.loadSelectedProducts();
      // Force component refresh by updating selectedProductsData
      this.selectedProductsData = [...this.selectedProductsData];
    }
  }

  // Computed properties for conditional rendering
  get showFilterScreen() {
    return this.currentView === "filter";
  }

  get showTableScreen() {
    return this.currentView === "table";
  }

  get showDetailScreen() {
    return this.currentView === "detail";
  }

  get showTermScreen() {
    const show = this.currentView === "terms";
    console.log("showTermScreen:", show, "currentView:", this.currentView);
    return show;
  }

  get showUserDetailScreen() {
    return this.currentView === "user-detail";
  }

  // Calculate total price for selected products with tax
  calculateSelectedProductsTotalPrice() {
    console.log(
      "Starting price calculation for",
      this.selectedProductsData?.length || 0,
      "products"
    );

    try {
      let totalPrice = 0;

      if (
        this.selectedProductsData &&
        Array.isArray(this.selectedProductsData)
      ) {
        // Use for loop instead of forEach for better performance and debugging
        for (let i = 0; i < this.selectedProductsData.length; i++) {
          const product = this.selectedProductsData[i];

          if (!product) {
            console.warn(`Product at index ${i} is null or undefined`);
            continue;
          }

          // Get unit price with optimized logic and safety checks
          let unitPrice = this.extractProductPrice(product);

          // Validate price is a valid number
          if (isNaN(unitPrice) || unitPrice < 0) {
            console.warn(
              `Invalid price for product ${product.Name || product.name}: ${unitPrice}`
            );
            unitPrice = 0;
          }

          // Get quantity (default to 1 if not specified) with validation
          let quantity = parseInt(product.quantity) || 1;
          if (isNaN(quantity) || quantity < 1) {
            quantity = 1;
          }

          // Add to total (unitPrice * quantity) with overflow protection
          const productTotal = unitPrice * quantity;
          if (isFinite(productTotal)) {
            totalPrice += productTotal;
          } else {
            console.warn(
              `Invalid product total calculation for ${product.Name}: ${productTotal}`
            );
          }
        }
      }

      // Add 10% tax to the total with validation
      const totalWithTax = totalPrice * 1.1;

      if (isFinite(totalWithTax) && totalWithTax >= 0) {
        this.selectedProductTotalPrice = totalWithTax;
        console.log("Price calculation completed. Total:", totalWithTax);
      } else {
        console.error("Invalid total price calculation:", totalWithTax);
        this.selectedProductTotalPrice = 0;
      }
    } catch (error) {
      console.error("Error in price calculation:", error);
      this.selectedProductTotalPrice = 0;
    }
  }

  // Helper method to extract price from product with optimized logic
  extractProductPrice(product) {
    // Priority-based price extraction with early returns for better performance

    // 1. First, try the Price field that's added by filterProductTableComponent
    if (product.Price != null && !isNaN(product.Price) && product.Price > 0) {
      return parseFloat(product.Price);
    }

    // 2. Try to get from PricebookEntries if Price field is missing
    if (
      product.PricebookEntries &&
      Array.isArray(product.PricebookEntries) &&
      product.PricebookEntries.length > 0
    ) {
      const unitPrice = product.PricebookEntries[0].UnitPrice;
      if (unitPrice != null && !isNaN(unitPrice) && unitPrice > 0) {
        return parseFloat(unitPrice);
      }
    }

    // 3. Try various other price field names in order of preference
    const priceFields = [
      "Price__c",
      "List_Price__c",
      "Unit_Price__c",
      "UnitPrice",
      "unitPrice",
      "price"
    ];

    for (const field of priceFields) {
      const value = product[field];
      if (value != null && !isNaN(value) && value > 0) {
        return parseFloat(value);
      }
    }

    // If no valid price found, return 0
    console.warn(
      `No valid price found for product: ${product.Name || product.name}`
    );
    return 0;
  }

  // Handle ProductTermComponent events
  handleMainOptionChange(event) {
    const { mainOption } = event.detail;
    this.selectedMainOption = mainOption;
    console.log("Main option changed:", mainOption);
  }

  handleProductTermChange(event) {
    const { productTerm } = event.detail;
    this.selectedProductTerm = productTerm;
    console.log("Product term changed:", productTerm);
  }

  handleAddToCart(event) {
    const { mainOption, productTerm, planDetails } = event.detail;

    // Store the selected payment terms
    this.selectedMainOption = mainOption;
    this.selectedProductTerm = productTerm;

    console.log("Add to cart with terms:", {
      mainOption,
      productTerm,
      planDetails
    });

    // Navigate to detail screen
    this.currentView = "detail";
  }

  // Computed properties for pill button CSS classes
  get homeTypeSingleFamilyClass() {
    return this.selectedHomeType === "singleFamily"
      ? "pill-button selected"
      : "pill-button";
  }

  get homeTypeApartmentClass() {
    return this.selectedHomeType === "apartment"
      ? "pill-button selected"
      : "pill-button";
  }

  get homeTypeTrailerClass() {
    return this.selectedHomeType === "trailer"
      ? "pill-button selected"
      : "pill-button";
  }

  get ownershipTypeOwnClass() {
    return this.selectedOwnershipType === "own"
      ? "pill-button selected"
      : "pill-button";
  }

  get ownershipTypeRentClass() {
    return this.selectedOwnershipType === "rent"
      ? "pill-button selected"
      : "pill-button";
  }

  get waterTypeMunicipalClass() {
    return this.selectedWaterType === "municipal"
      ? "pill-button selected"
      : "pill-button";
  }

  get waterTypeWellClass() {
    return this.selectedWaterType === "well"
      ? "pill-button selected"
      : "pill-button";
  }

  get drinkingWaterSourceBottleClass() {
    return this.selectedDrinkingWaterSource === "bottle"
      ? "pill-button selected"
      : "pill-button";
  }

  get drinkingWaterSourceTapClass() {
    return this.selectedDrinkingWaterSource === "tap"
      ? "pill-button selected"
      : "pill-button";
  }

  showToast(title, message, variant) {
    const event = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(event);
  }
}
