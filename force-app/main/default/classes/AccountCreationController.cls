public with sharing class AccountCreationController {
@AuraEnabled
    public static string createAccountFromUserDetails(String firstName,String lastName,String emailAddress,String phoneNumber,String street,String city,String province,String postalCode,String country){
        return createAccountFromUserDetailsInternal(firstName, lastName, emailAddress, phoneNumber, street, city, province, postalCode, country, null, null, null);
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isZipCodeServiceable(String zipCode) {
        return ZipCodeController.checkServiceability(zipCode);
    }
    
    
    @AuraEnabled
    public static string createAccountAndOrder(String firstName,String lastName,String emailAddress,String phoneNumber,String street,String city,String province,String postalCode,String country, String selectedProducts, String selectedProductTerm, String zipCodeFromComponent){
        return createAccountFromUserDetailsInternal(firstName, lastName, emailAddress, phoneNumber, street, city, province, postalCode, country, selectedProducts, selectedProductTerm, zipCodeFromComponent);
    }
    
    private static string createAccountFromUserDetailsInternal(String firstName,String lastName,String emailAddress,String phoneNumber,String street,String city,String province,String postalCode,String country, String selectedProducts, String selectedProductTerm, String zipCodeFromComponent){
        try {
            if(String.isBlank(firstName) || String.isBlank(lastName) || String.isBlank(emailAddress)){
                throw new AuraHandledException('Required fields are missing: First Name, Last Name, and Email are required.');
            }
            
            
            RecordType personAccountRT = [SELECT Id FROM RecordType WHERE SObjecttype =: 'Account' AND DeveloperName = 'PersonAccount' LIMIT 1];

            Account acc = new Account();
            acc.RecordTypeId = personAccountRT.Id;
            acc.FirstName = firstName;
            acc.LastName = lastName;
            acc.PersonEmail = emailAddress;

            if(String.isNotBlank(phoneNumber)){
                acc.PersonMobilePhone = phoneNumber;
                acc.Phone = phoneNumber;
            }

            


            
            if(String.isNotBlank(street))acc.PersonMailingStreet = street;
            if(String.isNotBlank(city))acc.PersonMailingCity = city;
           
            if(String.isNotBlank(postalCode))acc.PersonMailingPostalCode = postalCode;
            if(String.isNotBlank(country))acc.PersonMailingCountry = country;
            
           
            if(String.isNotBlank(street))acc.BillingStreet = street;acc.ShippingStreet = street;
            if(String.isNotBlank(city))acc.BillingCity = city;acc.ShippingCity = city;
            
            if(String.isNotBlank(postalCode))acc.BillingPostalCode = postalCode;acc.ShippingPostalCode = postalCode;
            if(String.isNotBlank(country))acc.BillingCountry = country;acc.ShippingCountry = country;

            insert acc;
            
            String resultMessage = 'SUCCESS:Person Account created successfully with ID: ' + acc.Id;
            
            
            if(String.isNotBlank(selectedProducts)) {
                try {
                    String orderResult = createOrderWithProducts(acc.Id, selectedProducts, selectedProductTerm, zipCodeFromComponent);
                    resultMessage += '. ' + orderResult;
                } catch(Exception orderException) {
                    System.debug('Order creation failed: ' + orderException.getMessage());
                    resultMessage += '. Note: Order creation failed - ' + orderException.getMessage();
                }
            }
            
            return resultMessage;
        } 
        catch (QueryException e) {
            System.debug('Query Exception: ' + e.getMessage());
            throw new AuraHandledException('Person Account record type not found. Please ensure Person Accounts are enabled in your org.');
        } catch (DmlException e) {
            System.debug('DML Exception: ' + e.getMessage());
            throw new AuraHandledException('Error creating Person Account: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            System.debug('Exception Type: ' + e.getTypeName());
            System.debug('Exception Message: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            System.debug('Line Number: ' + e.getLineNumber());
            throw new AuraHandledException('Unexpected error: ' + e.getTypeName() + ' - ' + e.getMessage());
        }
    }
    
    
    private static String createOrderWithProducts(Id accountId, String selectedProductsJson, String selectedProductTerm, String zipCodeFromComponent) {
        try {
            System.debug('=== ORDER CREATION DEBUG ===');
            System.debug('AccountId: ' + accountId);
            System.debug('selectedProductsJson: ' + selectedProductsJson);
            System.debug('selectedProductTerm: ' + selectedProductTerm);
            
            if(String.isBlank(selectedProductsJson)) {
                System.debug('selectedProductsJson is blank!');
                return 'No product data provided to create order';
            }
            
            List<Object> productList = (List<Object>) JSON.deserializeUntyped(selectedProductsJson);
            System.debug('Parsed productList: ' + productList);
            System.debug('ProductList size: ' + (productList != null ? String.valueOf(productList.size()) : 'null'));
            
            if(productList == null || productList.isEmpty()) {
                System.debug('ProductList is null or empty after parsing');
                return 'No products to create order - parsed list is empty';
            }
            
            // STEP 1: Validate products first - prepare OrderItems data
            List<OrderItem> orderItemsToCreate = new List<OrderItem>();
            Set<String> productIds = new Set<String>();
            
            System.debug('=== STEP 1: Validating products and preparing OrderItems ===');
            
            for(Object productObj : productList) {
                Map<String, Object> product = (Map<String, Object>) productObj;
                String productId = (String) product.get('Id');
                
                System.debug('Processing product: ' + product + ' with ID: ' + productId);
                
                if(String.isNotBlank(productId)) {
                    productIds.add(productId);
                    
                    // Prepare OrderItem (but don't set OrderId yet)
                    OrderItem orderItem = new OrderItem();
                    orderItem.Product2Id = productId;
                    
                    // Handle Quantity from product data
                    Object quantityObj = product.get('quantity');
                    if(quantityObj != null) {
                        try {
                            orderItem.Quantity = Integer.valueOf(String.valueOf(quantityObj));
                        } catch(Exception qtyEx) {
                            System.debug('Error parsing quantity: ' + quantityObj + ', setting to 1');
                            orderItem.Quantity = 1; // Default quantity
                        }
                    } else {
                        orderItem.Quantity = 1; // Default quantity
                    }
                    
                    // Handle UnitPrice from product data
                    Object unitPriceObj = product.get('unitPrice');
                    if(unitPriceObj != null && String.valueOf(unitPriceObj) != '0.00' && String.valueOf(unitPriceObj) != '0') {
                        try {
                            orderItem.UnitPrice = Decimal.valueOf(String.valueOf(unitPriceObj));
                        } catch(Exception priceEx) {
                            System.debug('Error parsing price: ' + unitPriceObj + ', setting to 1');
                            orderItem.UnitPrice = 1; // Set minimum price
                        }
                    } else {
                        orderItem.UnitPrice = 1; // Set minimum price instead of 0
                    }
                    
                    System.debug('Prepared OrderItem: Product2Id=' + orderItem.Product2Id + ', Quantity=' + orderItem.Quantity + ', UnitPrice=' + orderItem.UnitPrice);
                    orderItemsToCreate.add(orderItem);
                } else {
                    System.debug('Skipping product with blank ID: ' + product);
                }
            }
            
            if(orderItemsToCreate.isEmpty()) {
                System.debug('No valid products found for OrderItems');
                return 'No valid products found to create order';
            }
            
            // Validate that products exist in Salesforce
            List<Product2> existingProducts = [SELECT Id, Name FROM Product2 WHERE Id IN :productIds];
            System.debug('Found ' + existingProducts.size() + ' existing products out of ' + productIds.size() + ' requested');
            
            if(existingProducts.isEmpty()) {
                return 'None of the selected products exist in Salesforce';
            }
            
            System.debug('=== STEP 2: Creating Order ===');
            
            // Get Standard Pricebook (required for Orders)
            Pricebook2 standardPricebook = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
            System.debug('Using Pricebook: ' + standardPricebook.Id);
            
            // Get PricebookEntries for the products in the standard pricebook
            Map<String, PricebookEntry> productToPricebookEntry = new Map<String, PricebookEntry>();
            List<PricebookEntry> pricebookEntries = [SELECT Id, Product2Id, UnitPrice FROM PricebookEntry 
                                                    WHERE Product2Id IN :productIds 
                                                    AND Pricebook2Id = :standardPricebook.Id 
                                                    AND IsActive = true];
            
            System.debug('Found ' + pricebookEntries.size() + ' PricebookEntries');
            
            for(PricebookEntry pbe : pricebookEntries) {
                productToPricebookEntry.put(pbe.Product2Id, pbe);
                System.debug('PricebookEntry: Product2Id=' + pbe.Product2Id + ', Id=' + pbe.Id + ', UnitPrice=' + pbe.UnitPrice);
            }
            
            if(productToPricebookEntry.isEmpty()) {
                return 'No products have active pricebook entries in the standard pricebook. Please add products to the standard pricebook first.';
            }

            Account linkedAccount = [SELECT BillingStreet,billingCity,BillingState,BillingPostalCode,BillingCountry,ShippingStreet,ShippingCity,ShippingPostalCode,ShippingCountry,ShippingState FROM Account WHERE Id =:accountId];
            

            Contract newContract = new Contract();
            newContract.Status = 'Draft';
            // Handle "upfront" as a single-term contract
            if(selectedProductTerm.equalsIgnoreCase('upfront')) {
                newContract.ContractTerm = 1;
            } else {
                newContract.ContractTerm = Integer.valueOf(selectedProductTerm);
            }
            newContract.AccountId = linkedAccount.Id;
            newContract.BillingStreet = linkedAccount.BillingStreet;
            newContract.BillingCity = linkedAccount.BillingCity;
            newContract.BillingState = linkedAccount.BillingState;
            newContract.BillingPostalCode = linkedAccount.BillingPostalCode;
            newContract.BillingCountry = linkedAccount.BillingCountry;
            insert newContract;
            
            newContract.Status = 'Activated';
            update newContract;



            Order newOrder = new Order();
            newOrder.AccountId = accountId;
            newOrder.Status = 'Draft';
            newOrder.EffectiveDate = Date.today();
            newOrder.Type = 'Service';
            newOrder.Pricebook2Id = standardPricebook.Id;
            newOrder.BillingStreet = linkedAccount.BillingStreet;
            newOrder.BillingCity = linkedAccount.BillingCity;
            newOrder.BillingState = linkedAccount.BillingState;
            newOrder.BillingPostalCode = linkedAccount.BillingPostalCode;
            newOrder.BillingCountry = linkedAccount.BillingCountry;
            newOrder.ShippingStreet = linkedAccount.ShippingStreet;
            newOrder.ShippingCity = linkedAccount.ShippingCity;
            newOrder.ShippingPostalCode = linkedAccount.ShippingPostalCode;
            newOrder.ShippingCountry = linkedAccount.ShippingCountry;
            newOrder.ShippingState = linkedAccount.ShippingState;
            newOrder.ContractId = newContract.Id;
            
            // Set Installation Type dynamically based on zip code serviceability
            // Always use zipcode from zipCodeComponent for self and tech install
            String zipCodeToCheck = zipCodeFromComponent;
            System.debug('=== ZIP CODE SERVICEABILITY CHECK ===');
            System.debug('ZipCode from Component: "' + zipCodeFromComponent + '"');
            System.debug('zipCodeFromComponent isNotBlank: ' + String.isNotBlank(zipCodeFromComponent));
            
            if(String.isNotBlank(zipCodeToCheck)) {
                try {
                    // Clean up the zip code - remove spaces and take only the first 5 digits if it's a ZIP+4
                    String cleanZipCode = zipCodeToCheck.trim();
                    if(cleanZipCode.contains('-') && cleanZipCode.length() > 5) {
                        cleanZipCode = cleanZipCode.substring(0, 5); // Take only first 5 digits
                    }
                    System.debug('Cleaned Zip Code: ' + cleanZipCode);
                    
                    // Check what ServiceTerritory records exist
                    List<ServiceTerritory> allTerritories = [SELECT Id, Name, PostalCode FROM ServiceTerritory WHERE PostalCode != null LIMIT 10];
                    System.debug('Sample ServiceTerritory PostalCodes: ');
                    for(ServiceTerritory st : allTerritories) {
                        System.debug('  - ' + st.PostalCode + ' (Territory: ' + st.Name + ')');
                    }
                    
                    Boolean isServiceable = ZipCodeController.checkServiceability(cleanZipCode);
                    System.debug('Serviceability Result: ' + isServiceable);
                    
                    // If the cleaned zip code doesn't work, try the original
                    if(!isServiceable && !cleanZipCode.equals(zipCodeToCheck.trim())) {
                        System.debug('Trying original zip code: ' + zipCodeToCheck.trim());
                        isServiceable = ZipCodeController.checkServiceability(zipCodeToCheck.trim());
                        System.debug('Original Zip Code Serviceability Result: ' + isServiceable);
                    }
                    
                    // If zipcode came from component and component showed it as serviceable, 
                    // but our check shows false, force it to be serviceable
                    if(!isServiceable && String.isNotBlank(zipCodeFromComponent)) {
                        System.debug('ZipCode from component but showing as non-serviceable. Checking component verification...');
                        // Use the same method the component uses
                        Boolean componentServiceability = isZipCodeServiceable(zipCodeFromComponent.trim());
                        System.debug('Component serviceability check result: ' + componentServiceability);
                        if(componentServiceability) {
                            isServiceable = true;
                            System.debug('Overriding serviceability to TRUE based on component verification');
                        }
                    }
                    
                    // TEMPORARY FIX: If zipcode from component is null but we have a zipcode that should be serviceable
                    // Check if the zipcode being used would be serviceable using our method
                    if(!isServiceable && String.isBlank(zipCodeFromComponent)) {
                        System.debug('ZipCode from component is null. Checking if current zipcode should be serviceable...');
                        // Try to check serviceability of the current zipcode using our method
                        Boolean shouldBeServiceable = isZipCodeServiceable(cleanZipCode);
                        System.debug('Current zipcode serviceability check: ' + shouldBeServiceable);
                        if(shouldBeServiceable) {
                            isServiceable = true;
                            System.debug('Overriding serviceability to TRUE - zipcode should be serviceable');
                        }
                    }
                    
                    newOrder.Installation_Type__c = isServiceable ? 'Tech Install' : 'Self Install';
                    System.debug('Final Installation Type: ' + newOrder.Installation_Type__c);
                    
                } catch(Exception zipEx) {
                    System.debug('Error checking zip code serviceability: ' + zipEx.getMessage());
                    System.debug('Exception Stack Trace: ' + zipEx.getStackTraceString());
                    newOrder.Installation_Type__c = 'Tech Install'; // Default to Tech Install if check fails
                }
            } else {
                System.debug('No zip code available - defaulting to Tech Install');
                newOrder.Installation_Type__c = 'Tech Install'; // Default to Tech Install if no zip code
            }
            
            
            insert newOrder;
            System.debug('Created Order: ' + newOrder.Id);
            
            System.debug('=== STEP 3: Creating OrderItems ===');
            
            // Now create OrderItems with PricebookEntryId (required field)
            List<OrderItem> finalOrderItems = new List<OrderItem>();
            
            for(OrderItem item : orderItemsToCreate) {
                PricebookEntry pbe = productToPricebookEntry.get(item.Product2Id);
                
                if(pbe != null) {
                    OrderItem finalItem = new OrderItem();
                    finalItem.OrderId = newOrder.Id;
                    finalItem.PricebookEntryId = pbe.Id; // Use PricebookEntryId instead of Product2Id
                    finalItem.Quantity = item.Quantity;
                    
                    // Use price from PricebookEntry or the original price and add 10% tax
                    Decimal basePrice;
                    if(item.UnitPrice != null && item.UnitPrice > 0) {
                        basePrice = item.UnitPrice;
                    } else {
                        basePrice = pbe.UnitPrice;
                    }
                    
                    // Add 10% tax to the unit price
                    finalItem.UnitPrice = basePrice * 1.10;
                    if(String.isNotBlank(selectedProductTerm))finalItem.Product_Terms__c = selectedProductTerm;
                    
                    System.debug('Final OrderItem: OrderId=' + finalItem.OrderId + ', PricebookEntryId=' + finalItem.PricebookEntryId + ', Quantity=' + finalItem.Quantity + ', UnitPrice=' + finalItem.UnitPrice);
                    finalOrderItems.add(finalItem);
                } else {
                    System.debug('No PricebookEntry found for Product2Id: ' + item.Product2Id);
                }
            }
            
            if(!finalOrderItems.isEmpty()) {
                try {
                    System.debug('Inserting ' + finalOrderItems.size() + ' OrderItems');
                    insert finalOrderItems;
                    System.debug('Successfully inserted OrderItems');
                    String invoiceResult = createInvoicesBasedOnTerms(newOrder.Id,accountId,selectedProductTerm,finalOrderItems);
                    return 'Order created successfully with ID: ' + newOrder.Id + ' and ' + finalOrderItems.size() + ' product(s). '+invoiceResult;
                } catch(DmlException dmlEx) {
                    System.debug('DmlException inserting OrderItems: ' + dmlEx.getMessage());
                    for(Integer i = 0; i < dmlEx.getNumDml(); i++) {
                        System.debug('DML Error ' + i + ': ' + dmlEx.getDmlMessage(i));
                        System.debug('Failed record: ' + dmlEx.getDmlId(i));
                    }
                    return 'Order created with ID: ' + newOrder.Id + ' but failed to add products: ' + dmlEx.getMessage();
                }
            } else {
                return 'Order created but no valid products found';
            }
            
        } catch(Exception e) {
            System.debug('Error creating order: ' + e.getMessage());
            throw new AuraHandledException('Error creating order: ' + e.getMessage());
        }
    }
    
    // Helper method to get Product2Id from OrderItem
    private static Id getProduct2IdFromOrderItem(OrderItem orderItem) {
        try {
            if(orderItem.PricebookEntryId != null) {
                PricebookEntry pbe = [SELECT Product2Id FROM PricebookEntry WHERE Id = :orderItem.PricebookEntryId LIMIT 1];
                return pbe.Product2Id;
            }
        } catch(Exception e) {
            System.debug('Error getting Product2Id from OrderItem: ' + e.getMessage());
        }
        return null;
    }


    private static Id getContractIdFromAccount(Id accountId){
    try {
        if(accountId != null){
            List<Contract> contracts = [SELECT Id FROM Contract WHERE AccountId = :accountId LIMIT 1];
            if (!contracts.isEmpty()) {
                return contracts[0].Id;
            }
        }
    } catch (Exception e) {
      System.debug('Error getting contractID from contract: ' + e.getMessage());
    }
    return null;
}
    
    // Create invoices based on product terms
    private static String createInvoicesBasedOnTerms(Id orderId, Id accountId, String selectedProductTerm, List<OrderItem> orderItems) {
        try {
            System.debug('=== INVOICE CREATION DEBUG ===');
            System.debug('OrderId: ' + orderId);
            System.debug('AccountId: ' + accountId);
            System.debug('SelectedProductTerm: ' + selectedProductTerm);
            System.debug('OrderItems count: ' + (orderItems != null ? orderItems.size() : 0));
            
            // Validate input parameters
            if(String.isBlank(selectedProductTerm) || orderItems == null || orderItems.isEmpty()) {
                System.debug('Invalid parameters for invoice creation');
                return 'No invoices created - missing product term or order items';
            }
            
            // Parse product term to get number of invoices to create
            Integer numberOfInvoices;
            try {
                // Handle "upfront" as a single payment (1 invoice)
                if(selectedProductTerm.equalsIgnoreCase('upfront')) {
                    numberOfInvoices = 1;
                    System.debug('Upfront payment detected - creating 1 invoice');
                } else {
                    numberOfInvoices = Integer.valueOf(selectedProductTerm);
                }
            } catch(Exception e) {
                System.debug('Error parsing product term: ' + selectedProductTerm);
                return 'Invalid product term format - cannot create invoices';
            }
            
            if(numberOfInvoices <= 0) {
                System.debug('Invalid number of invoices: ' + numberOfInvoices);
                return 'Invalid product term - must be greater than 0';
            }
            
            System.debug('Creating ' + numberOfInvoices + ' invoices');
            
            // Get account billing information
            Account myAccount = [SELECT Id, Name, BillingStreet, BillingCity, BillingState, 
                                BillingPostalCode, BillingCountry 
                                FROM Account WHERE Id = :accountId LIMIT 1];
            
            // Calculate amount per invoice (divide total order amount by number of invoices)
            Decimal totalOrderAmount = 0;
            for(OrderItem item : orderItems) {
                totalOrderAmount += (item.UnitPrice * item.Quantity);
            }
            
            System.debug('Total order amount: ' + totalOrderAmount);
            
            Date baseInvoiceDate = Date.today();
            Integer totalInvoicesCreated = 0;
            Integer totalInvoiceLinesCreated = 0;
            
            // Id contractId = [SELECT Id FROM Contract WHERE AccountId =: accountId].Id;
            // Create invoices one by one following the provided pattern
            for(Integer i = 1; i <= numberOfInvoices; i++) {
                try {
                    // Initialize totals for THIS specific invoice
                    Decimal invoiceChargeAmountWithTax = 0.0;
                    Decimal invoiceChargeTax = 0.0;
                    
                    // 1. Create the Invoice record
                    Invoice__c newInvoice = new Invoice__c();
                    newInvoice.BillingAccountId__c = accountId;
                    newInvoice.InvoiceDate__c = baseInvoiceDate.addMonths(i - 1);
                    newInvoice.DueDate__c = baseInvoiceDate.addMonths(i - 1);
                    newInvoice.ReferenceEntityId__c = orderId;
                    newInvoice.Status__c = 'Draft';
                    // newInvoice.BillToContactId__c = contractId;

                    // Note: Using available standard fields only
                    
                    // 4. Insert the invoice
                    insert newInvoice;
                    totalInvoicesCreated++;
                    System.debug('Successfully created Invoice ' + i + ' with ID: ' + newInvoice.Id);
                    
                    // Create invoice line items for this invoice
                    List<InvoiceLine__c> invoiceLineItems = new List<InvoiceLine__c>();
                    
                    for(OrderItem orderItem : orderItems) {
                        // 2. Create the Invoice Line Item
                        InvoiceLine__c invoiceLineItem = new InvoiceLine__c();
                        invoiceLineItem.InvoiceId__c = newInvoice.Id;
                        invoiceLineItem.TaxRate__c = 10;
                        invoiceLineItem.ReferenceEntityItemId__c = orderItem.Id;
                        invoiceLineItem.Type__c = 'Product';
                        invoiceLineItem.Quantity__c = orderItem.Quantity;
                        invoiceLineItem.Product2Id__c = getProduct2IdFromOrderItem(orderItem);
                        
                        // Calculate unit price based on payment term
                        Decimal baseUnitPrice = orderItem.UnitPrice / 1.10; // Remove tax first
                        Decimal finalUnitPrice;
                        
                        if(selectedProductTerm.equalsIgnoreCase('upfront')) {
                            // For upfront payment, use full amount (don't divide)
                            finalUnitPrice = baseUnitPrice * orderItem.Quantity;
                        } else {
                            // For installment payments, divide by number of terms
                            finalUnitPrice = (baseUnitPrice / numberOfInvoices) * orderItem.Quantity;
                        }
                        
                        Decimal taxPrice = finalUnitPrice * 0.10;
                        
                        invoiceLineItem.UnitPrice__c = finalUnitPrice;
                        invoiceLineItem.TaxAmount__c = taxPrice;

                        invoiceLineItem.ChargeAmount__c = finalUnitPrice;
                        invoiceLineItem.Charge_Amount_with_Tax__c = finalUnitPrice + taxPrice;
                        invoiceLineItem.ChargeTaxAmount__c = taxPrice;

                        // Add to THIS invoice's totals only
                        invoiceChargeAmountWithTax += invoiceLineItem.Charge_Amount_with_Tax__c;
                        invoiceChargeTax += invoiceLineItem.ChargeTaxAmount__c;
                        
                        // Set invoice line dates
                        invoiceLineItem.InvoiceLineStartDate__c = newInvoice.InvoiceDate__c;
                        invoiceLineItem.InvoiceLineEndDate__c = newInvoice.InvoiceDate__c.addMonths(1).addDays(-1);
                        
                        invoiceLineItems.add(invoiceLineItem);
                        
                        System.debug('Prepared InvoiceLine for Invoice ' + i + 
                                   ': Quantity=' + invoiceLineItem.Quantity__c + 
                                   ', UnitPrice=' + invoiceLineItem.UnitPrice__c + 
                                   ', ChargeAmountWithTax=' + invoiceLineItem.Charge_Amount_with_Tax__c);
                    }
                    
                    // Insert invoice line items
                    if(!invoiceLineItems.isEmpty()) {
                        try {
                            // Update invoice totals with THIS invoice's calculated amounts
                            newInvoice.TotalChargeAmountWithTax__c = invoiceChargeAmountWithTax;
                            newInvoice.TotalChargeTaxAmount__c = invoiceChargeTax;
                            newInvoice.Balance__c = invoiceChargeAmountWithTax;
                            // newInvoice.BillToContactId__c = getContractIdFromAccount(accountId);
                            update newInvoice;
                            
                            System.debug('Updated Invoice ' + i + ' totals: ChargeAmountWithTax=' + invoiceChargeAmountWithTax + 
                                       ', ChargeTax=' + invoiceChargeTax + ', Balance=' + invoiceChargeAmountWithTax);
                            
                            insert invoiceLineItems;
                            totalInvoiceLinesCreated += invoiceLineItems.size();
                            System.debug('Successfully inserted ' + invoiceLineItems.size() + ' invoice line items for Invoice ' + i);
                        } catch(DmlException lineItemEx) {
                            System.debug('Error creating invoice line items for Invoice ' + i + ': ' + lineItemEx.getMessage());
                        }
                    }
                    
                } catch(DmlException invoiceEx) {
                    System.debug('Error creating Invoice ' + i + ': ' + invoiceEx.getMessage());
                    if(i == 1) {
                        // If first invoice fails, return error message
                        return 'Note: Invoices could not be created due to org restrictions. Order created successfully.';
                    }
                }
            }
            
            return totalInvoicesCreated + ' invoices created successfully with ' + totalInvoiceLinesCreated + ' invoice line items';
            
        } catch(Exception e) {
            System.debug('Error in createInvoicesBasedOnTerms: ' + e.getMessage());
            return 'Error creating invoices: ' + e.getMessage();
        }
    }
}
