public with sharing class PostPaymentOrderProcessingController {
    
    /**
     * Main entry point for processing orders after successful payment
     * Simplified version that delegates to helper methods
     */
    @AuraEnabled
    public static String processPaymentCompletedOrder(String orderId, String paymentIntentId) {
        System.debug('=== Starting processPaymentCompletedOrder ===');
        System.debug('Order ID: ' + orderId);
        System.debug('Payment Intent ID: ' + paymentIntentId);
        
        try {
            // Verify the order exists and get its installation type
            List<Order> orders = [
                SELECT Id, Installation_Type__c, AccountId, Status, TotalAmount, 
                       EffectiveDate, OrderNumber, Account.Name
                FROM Order 
                WHERE Id = :orderId 
                LIMIT 1
            ];
            
            if (orders.isEmpty()) {
                return createErrorResponse('Order not found with ID: ' + orderId);
            }
            
            Order order = orders[0];
            System.debug('Found order: ' + order.OrderNumber + ' | Installation Type: ' + order.Installation_Type__c);
            
            if (String.isBlank(order.Installation_Type__c)) {
                return createErrorResponse('Installation Type is not set on the order. Please set the installation type first.');
            }
            
            // Update order status to indicate payment is complete
            order.Status = 'Activated';
            update order;
            System.debug('Updated order status to Activated');
            
            String result = '';
            
            // Process based on installation type
            if (order.Installation_Type__c == 'Self Install') {
                System.debug('Processing Self Install - Creating Fulfillment Order');
                result = processSelfInstallOrder(order, paymentIntentId);
            } else if (order.Installation_Type__c == 'Tech Install') {
                System.debug('Processing Tech Install - Creating Installation Order');
                result = processTechInstallOrder(order, paymentIntentId);
            } else {
                // Handle case where installation type is not set or unknown
                // Check zip code serviceability to determine the right path
                System.debug('Installation type not set or unknown: ' + order.Installation_Type__c);
                System.debug('Checking zip code serviceability to determine processing path...');
                
                String zipCode = getZipCodeFromOrder(order);
                if (String.isNotBlank(zipCode)) {
                    Boolean isServiceable = ZipCodeController.checkServiceability(zipCode);
                    System.debug('Zip code ' + zipCode + ' serviceability: ' + isServiceable);
                    
                    if (isServiceable) {
                        System.debug('Zip code is serviceable - processing as Tech Install');
                        result = processTechInstallOrder(order, paymentIntentId);
                    } else {
                        System.debug('Zip code is NOT serviceable - creating fulfillment order for self install');
                        result = createFulfillmentOrderForNonServiceableOrder(order, paymentIntentId, zipCode);
                    }
                } else {
                    System.debug('No zip code found - defaulting to Tech Install');
                    result = processTechInstallOrder(order, paymentIntentId);
                }
            }
            
            System.debug('=== processOrderAfterPayment completed successfully ===');
            return result;
            
        } catch (Exception e) {
            System.debug('EXCEPTION in processOrderAfterPayment:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return createErrorResponse('Failed to process order after payment: ' + e.getMessage());
        }
    }
    
    /**
     * Processes Self Install orders by creating Fulfillment Order and Fulfillment Order Line Items
     */
    private static String processSelfInstallOrder(Order order, String paymentIntentId) {
        System.debug('=== Processing Self Install Order ===');
        
        try {
            // Create Fulfillment Order with proper linking to source Order
            Fulfillment_Order__c fulfillmentOrder = new Fulfillment_Order__c(
                Name = 'FO-' + order.OrderNumber,
                Account__c = order.AccountId,
                Order__c = order.Id,  // Link to source Order
                Order_Recipient__c = order.Account.Name,
                Status__c = 'Draft',
                Delivery_SLA__c = 'Standard'
                // Note: Payment_Intent_Id__c field may need to be deployed first
            );
            
            insert fulfillmentOrder;
            System.debug('Created Fulfillment Order: ' + fulfillmentOrder.Id);
            System.debug('Linked to source Order: ' + order.Id);
            
            // Get order line items to create fulfillment order line items
            List<OrderItem> orderItems = [
                SELECT Id, Product2Id, Product2.Name, Quantity, UnitPrice, TotalPrice,
                       Product2.Description, PricebookEntryId
                FROM OrderItem 
                WHERE OrderId = :order.Id
            ];
            
            System.debug('Found ' + orderItems.size() + ' order line items');
            
            if (!orderItems.isEmpty()) {
                List<Fulfillment_Order_Productt__c> fulfillmentLineItems = new List<Fulfillment_Order_Productt__c>();
                
                for (OrderItem item : orderItems) {
                    Fulfillment_Order_Productt__c lineItem = new Fulfillment_Order_Productt__c(
                        Name = fulfillmentOrder.Name + ' - ' + item.Product2.Name,
                        Fulfillment_Order__c = fulfillmentOrder.Id,  // Master-Detail to Fulfillment Order
                        Product__c = item.Product2Id,               // Lookup to Product
                        Account__c = order.AccountId,               // Lookup to Account
                        Order__c = order.Id,                       // Lookup to source Order
                        Order_Product__c = item.Id,                // Lookup to OrderItem
                        Quantity__c = item.Quantity,
                        Unit_Price__c = item.UnitPrice,
                        Gross_Unit_Price__c = item.UnitPrice,
                        Line_Subtotal__c = item.TotalPrice,
                        Description__c = item.Product2.Description
                    );
                    fulfillmentLineItems.add(lineItem);
                }
                
                insert fulfillmentLineItems;
                System.debug('Created ' + fulfillmentLineItems.size() + ' Fulfillment Order Line Items');
                System.debug('Each line item linked to: Fulfillment Order, Product, Account, Order, and OrderItem');
            }
            
            // Create success response
            Map<String, Object> response = new Map<String, Object>{
                'success' => true,
                'message' => 'Self Install order processed successfully',
                'installationType' => 'Self Install',
                'fulfillmentOrderId' => fulfillmentOrder.Id,
                'fulfillmentOrderName' => fulfillmentOrder.Name,
                'lineItemsCreated' => orderItems.size(),
                'nextSteps' => 'Fulfillment order created. Your items will be shipped to you for self-installation.',
                'orderStatus' => 'Activated'
            };
            
            return JSON.serialize(response);
            
        } catch (Exception e) {
            System.debug('Error processing Self Install order: ' + e.getMessage());
            throw e;
        }
    }
    
    /**
     * Processes Tech Install orders by creating Installation Order and Installation Order Products
     */
    private static String processTechInstallOrder(Order order, String paymentIntentId) {
        System.debug('=== Processing Tech Install Order ===');
        
        try {
            // Create Installation Order
            Installation_Order__c installationOrder = new Installation_Order__c(
                Name = 'IO-' + order.OrderNumber,
                Account__c = order.AccountId,
                Order_Recipient__c = order.Account.Name,
                Status__c = 'Draft',  // Using valid picklist value
                Created_Date__c = Date.today(),
                Type__c = 'Warehouse',  // Using valid picklist value
                Is_Suspended__c = false,
                Activated_Date__c = Date.today(),
                Installation_To_Email_Address__c = order.Account.PersonEmail
            );
            
            insert installationOrder;
            System.debug('Created Installation Order: ' + installationOrder.Id);
            
            // Get order line items to create installation order products
            List<OrderItem> orderItems = [
                SELECT Id, Product2Id, Product2.Name, Quantity, UnitPrice, TotalPrice,
                       Product2.Description, PricebookEntryId
                FROM OrderItem 
                WHERE OrderId = :order.Id
            ];
            
            System.debug('Found ' + orderItems.size() + ' order line items');
            
            if (!orderItems.isEmpty()) {
                List<Installation_Order_Product__c> installationProducts = new List<Installation_Order_Product__c>();
                
                for (OrderItem item : orderItems) {
                    Installation_Order_Product__c product = new Installation_Order_Product__c(
                        Name = installationOrder.Name + ' - ' + item.Product2.Name,
                        Installation_Order__c = installationOrder.Id,
                        Product__c = item.Product2Id,
                        Order_Product__c = item.Id,
                        Quantity__c = item.Quantity,
                        Unit_Price__c = item.UnitPrice,
                        Gross_Unit_Price__c = item.UnitPrice,
                        Line_Subtotal__c = item.TotalPrice,
                        Quantity_on_the_Original_Order__c = item.Quantity,
                        Description__c = item.Product2.Description,
                        ServiceDate__c = Date.today().addDays(3) // Default to 3 days from now
                    );
                    installationProducts.add(product);
                }
                
                insert installationProducts;
                System.debug('Created ' + installationProducts.size() + ' Installation Order Products');
            }
            
            // Create success response
            Map<String, Object> response = new Map<String, Object>{
                'success' => true,
                'message' => 'Tech Install order processed successfully',
                'installationType' => 'Tech Install',
                'installationOrderId' => installationOrder.Id,
                'installationOrderName' => installationOrder.Name,
                'installationOrderNumber' => installationOrder.Installation_Order_Number__c,
                'productsCreated' => orderItems.size(),
                'nextSteps' => 'Installation order created. A technician will contact you to schedule the installation.',
                'orderStatus' => 'Activated'
            };
            
            return JSON.serialize(response);
            
        } catch (Exception e) {
            System.debug('Error processing Tech Install order: ' + e.getMessage());
            throw e;
        }
    }
    
    /**
     * Creates a standardized error response
     */
    private static String createErrorResponse(String message) {
        Map<String, Object> errorResponse = new Map<String, Object>{
            'success' => false,
            'error' => true,
            'message' => message,
            'timestamp' => System.now()
        };
        
        return JSON.serialize(errorResponse);
    }
    
    /**
     * Creates fulfillment order and fulfillment order products for non-serviceable zip codes
     * This method is called when a zip code is not serviceable and we need to create a self-install order
     */
    @AuraEnabled
    public static String createFulfillmentOrderForNonServiceableZip(String zipCode, String accountId, List<String> productIds, String orderNumber) {
        System.debug('=== Creating Fulfillment Order for Non-Serviceable Zip Code ===');
        System.debug('Zip Code: ' + zipCode);
        System.debug('Account ID: ' + accountId);
        System.debug('Order Number: ' + orderNumber);
        System.debug('Product IDs: ' + productIds);
        
        try {
            // Validate input parameters
            if (String.isBlank(zipCode) || String.isBlank(accountId) || productIds == null || productIds.isEmpty()) {
                return createErrorResponse('Missing required parameters: zipCode, accountId, and productIds are required');
            }
            
            // Double-check that the zip code is indeed not serviceable
            if (ZipCodeController.checkServiceability(zipCode)) {
                return createErrorResponse('This zip code is serviceable. Use tech install process instead.');
            }
            
            // Get account information
            List<Account> accounts = [
                SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                       ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry
                FROM Account 
                WHERE Id = :accountId 
                LIMIT 1
            ];
            
            if (accounts.isEmpty()) {
                return createErrorResponse('Account not found with ID: ' + accountId);
            }
            
            Account account = accounts[0];
            
            // Get product information
            List<Product2> products = [
                SELECT Id, Name, Description, Family, ProductCode
                FROM Product2 
                WHERE Id IN :productIds AND IsActive = true
            ];
            
            if (products.isEmpty()) {
                return createErrorResponse('No valid active products found with the provided IDs');
            }
            
            // Create Fulfillment Order
            String fulfillmentOrderName = String.isNotBlank(orderNumber) ? 'FO-' + orderNumber : 'FO-NonServiceable-' + System.now().format('yyyyMMdd-HHmmss');
            
            Fulfillment_Order__c fulfillmentOrder = new Fulfillment_Order__c(
                Name = fulfillmentOrderName,
                Account__c = accountId,
                Order_Recipient__c = account.Name,
                Status__c = 'Draft',
                Delivery_SLA__c = 'Standard',
                Fulfillment_Action__c = 'Ship',
                Order_Processing_Stage__c = 'Non-Serviceable Zip Code - Self Install',
                // Set address on the main Fulfillment Order
                Fulfill_To_Address_Line1__c = String.isNotBlank(account.ShippingStreet) ? account.ShippingStreet : account.BillingStreet,
                Fulfilled_to_Address_City__c = String.isNotBlank(account.ShippingCity) ? account.ShippingCity : account.BillingCity,
                Fulfilled_To_Address_State__c = String.isNotBlank(account.ShippingState) ? account.ShippingState : account.BillingState,
                Fulfilled_To_Address_Postal_Code__c = zipCode,
                Fulfilled_to_Address_Country__c = String.isNotBlank(account.ShippingCountry) ? account.ShippingCountry : account.BillingCountry
            );
            
            insert fulfillmentOrder;
            System.debug('Created Fulfillment Order: ' + fulfillmentOrder.Id);
            
            // Create Fulfillment Order Products
            List<Fulfillment_Order_Productt__c> fulfillmentProducts = new List<Fulfillment_Order_Productt__c>();
            
            for (Product2 product : products) {
                Fulfillment_Order_Productt__c fulfillmentProduct = new Fulfillment_Order_Productt__c(
                    Name = fulfillmentOrderName + ' - ' + product.Name,
                    Fulfillment_Order__c = fulfillmentOrder.Id,
                    Product__c = product.Id,
                    Account__c = accountId,
                    Quantity__c = 1, // Default quantity, can be modified later
                    Description__c = product.Description,
                    Amazon_fulfillment_channel__c = 'MFN' // Merchant Fulfilled Network for self-install
                    // Note: Address fields are formula fields that reference parent Fulfillment Order
                    // They will be automatically populated based on the Fulfillment Order address fields
                );
                
                fulfillmentProducts.add(fulfillmentProduct);
            }
            
            if (!fulfillmentProducts.isEmpty()) {
                insert fulfillmentProducts;
                System.debug('Created ' + fulfillmentProducts.size() + ' Fulfillment Order Products');
            }
            
            // Create success response
            Map<String, Object> response = new Map<String, Object>{
                'success' => true,
                'message' => 'Fulfillment order created successfully for non-serviceable zip code',
                'fulfillmentOrderId' => fulfillmentOrder.Id,
                'fulfillmentOrderName' => fulfillmentOrder.Name,
                'zipCode' => zipCode,
                'accountId' => accountId,
                'accountName' => account.Name,
                'productsCreated' => fulfillmentProducts.size(),
                'deliveryType' => 'Self Install - Shipping Required',
                'reason' => 'Non-serviceable zip code - technician installation not available',
                'nextSteps' => 'Your products will be shipped to you for self-installation since this area is not covered by our technician services.',
                'shippingAddress' => new Map<String, Object>{
                    'street' => String.isNotBlank(account.ShippingStreet) ? account.ShippingStreet : account.BillingStreet,
                    'city' => String.isNotBlank(account.ShippingCity) ? account.ShippingCity : account.BillingCity,
                    'state' => String.isNotBlank(account.ShippingState) ? account.ShippingState : account.BillingState,
                    'postalCode' => zipCode,
                    'country' => String.isNotBlank(account.ShippingCountry) ? account.ShippingCountry : account.BillingCountry
                }
            };
            
            return JSON.serialize(response);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in createFulfillmentOrderForNonServiceableZip:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return createErrorResponse('Failed to create fulfillment order: ' + e.getMessage());
        }
    }
    
    /**
     * Enhanced method to process orders with automatic zip code validation
     * If order has tech install but zip is not serviceable, automatically converts to self-install
     */
    @AuraEnabled
    public static String processOrderWithZipValidation(String orderId, String invoiceId, String paymentIntentId, String zipCode) {
        System.debug('=== Processing Order with Zip Code Validation ===');
        System.debug('Order ID: ' + orderId);
        System.debug('Zip Code: ' + zipCode);
        
        try {
            // Get order details
            List<Order> orders = [
                SELECT Id, Installation_Type__c, AccountId, Status, TotalAmount, 
                       EffectiveDate, OrderNumber, Account.Name,
                       (SELECT Id, Product2Id FROM OrderItems)
                FROM Order 
                WHERE Id = :orderId 
                LIMIT 1
            ];
            
            if (orders.isEmpty()) {
                return createErrorResponse('Order not found with ID: ' + orderId);
            }
            
            Order order = orders[0];
            
            // Check zip code serviceability if provided
            if (String.isNotBlank(zipCode)) {
                Boolean isServiceable = ZipCodeController.checkServiceability(zipCode);
                System.debug('Zip Code ' + zipCode + ' serviceability: ' + isServiceable);
                
                // If zip code is not serviceable and order is set for Tech Install, 
                // automatically convert to Self Install
                if (!isServiceable && order.Installation_Type__c == 'Tech Install') {
                    System.debug('Converting Tech Install to Self Install due to non-serviceable zip code');
                    order.Installation_Type__c = 'Self Install';
                    update order;
                    
                    // Add note about the conversion in the response
                    String result = processPaymentCompletedOrder(orderId, paymentIntentId);
                    
                    // Parse and enhance the response to include conversion info
                    Map<String, Object> resultData = (Map<String, Object>) JSON.deserializeUntyped(result);
                    resultData.put('conversionReason', 'Order converted from Tech Install to Self Install due to non-serviceable zip code: ' + zipCode);
                    resultData.put('originalInstallationType', 'Tech Install');
                    resultData.put('zipCode', zipCode);
                    resultData.put('isZipServiceable', false);
                    
                    return JSON.serialize(resultData);
                }
            }
            
            // Process normally if no conversion needed
            return processPaymentCompletedOrder(orderId, paymentIntentId);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in processOrderWithZipValidation:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            return createErrorResponse('Failed to process order with zip validation: ' + e.getMessage());
        }
    }
    
    /**
     * Helper method to get available self-install products for non-serviceable areas
     */
    @AuraEnabled(cacheable=true)
    public static List<Product2> getSelfInstallProducts() {
        try {
            return [
                SELECT Id, Name, Description, Family, ProductCode, IsActive
                FROM Product2 
                WHERE IsActive = true 
                AND (Family = 'Self Install' OR Family = 'Shipping' OR Name LIKE '%Self%' OR ProductCode LIKE '%SELF%')
                ORDER BY Name
            ];
        } catch (Exception e) {
            System.debug('Error getting self-install products: ' + e.getMessage());
            return new List<Product2>();
        }
    }
    
    /**
     * Method to get order details including installation type (for debugging/testing)
     */
    @AuraEnabled(cacheable=true)
    public static String getOrderDetails(String orderId) {
        System.debug('=== Getting Order Details ===');
        System.debug('Order ID: ' + orderId);
        
        try {
            if (String.isBlank(orderId)) {
                return createErrorResponse('Order ID is required');
            }
            
            List<Order> orders = [
                SELECT Id, OrderNumber, Installation_Type__c, AccountId, Account.Name,
                       Status, TotalAmount, EffectiveDate, CreatedDate,
                       (SELECT Id, Product2Id, Product2.Name, Quantity, UnitPrice, TotalPrice 
                        FROM OrderItems)
                FROM Order 
                WHERE Id = :orderId 
                LIMIT 1
            ];
            
            if (orders.isEmpty()) {
                return createErrorResponse('Order not found with ID: ' + orderId);
            }
            
            Order order = orders[0];
            
            Map<String, Object> response = new Map<String, Object>{
                'success' => true,
                'order' => new Map<String, Object>{
                    'id' => order.Id,
                    'orderNumber' => order.OrderNumber,
                    'installationType' => order.Installation_Type__c,
                    'accountId' => order.AccountId,
                    'accountName' => order.Account.Name,
                    'status' => order.Status,
                    'totalAmount' => order.TotalAmount,
                    'effectiveDate' => order.EffectiveDate,
                    'createdDate' => order.CreatedDate,
                    'lineItemCount' => order.OrderItems.size()
                }
            };
            
            return JSON.serialize(response);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in getOrderDetails:');
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            return createErrorResponse('Failed to get order details: ' + e.getMessage());
        }
    }
    
    /**
     * Helper method to extract zip code from Order (billing or shipping)
     */
    private static String getZipCodeFromOrder(Order order) {
        try {
            // Get the account to access address information
            List<Account> accounts = [
                SELECT Id, BillingPostalCode, ShippingPostalCode
                FROM Account 
                WHERE Id = :order.AccountId 
                LIMIT 1
            ];
            
            if (!accounts.isEmpty()) {
                Account account = accounts[0];
                // Prefer shipping zip code, fallback to billing
                return String.isNotBlank(account.ShippingPostalCode) ? 
                       account.ShippingPostalCode : account.BillingPostalCode;
            }
        } catch (Exception e) {
            System.debug('Error getting zip code from order: ' + e.getMessage());
        }
        
        return null;
    }
    
    /**
     * Creates a fulfillment order specifically for orders that have non-serviceable zip codes
     * This is called from the main processing logic when zip code check fails
     */
    private static String createFulfillmentOrderForNonServiceableOrder(
        Order order, String paymentIntentId, String zipCode
    ) {
        System.debug('=== Creating Fulfillment Order for Non-Serviceable Order ===');
        System.debug('Order: ' + order.OrderNumber + ' | Zip Code: ' + zipCode);
        
        try {
            // Get order line items
            List<OrderItem> orderItems = [
                SELECT Id, Product2Id, Product2.Name, Quantity, UnitPrice, TotalPrice,
                       Product2.Description, PricebookEntryId
                FROM OrderItem 
                WHERE OrderId = :order.Id
            ];
            
            if (orderItems.isEmpty()) {
                return createErrorResponse('No order items found for order: ' + order.OrderNumber);
            }
            
            // Get account information for shipping
            List<Account> accounts = [
                SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingCountry,
                       ShippingStreet, ShippingCity, ShippingState, ShippingCountry, PersonEmail
                FROM Account 
                WHERE Id = :order.AccountId 
                LIMIT 1
            ];
            
            if (accounts.isEmpty()) {
                return createErrorResponse('Account not found for order: ' + order.OrderNumber);
            }
            
            Account account = accounts[0];
            
            // Create Fulfillment Order
            Fulfillment_Order__c fulfillmentOrder = new Fulfillment_Order__c(
                Name = 'FO-NonServiceable-' + order.OrderNumber,
                Account__c = order.AccountId,
                Order__c = order.Id,  // Link to the original order
                Order_Recipient__c = account.Name,
                Status__c = 'Draft',
                Delivery_SLA__c = 'Standard',
                Fulfillment_Action__c = 'Ship',
                Order_Processing_Stage__c = 'Non-Serviceable Zip - Self Install Required'
                // Note: Total_Quantity__c and Created_By__c may be formula fields or read-only
            );
            
            insert fulfillmentOrder;
            System.debug('✅ Created Fulfillment Order: ' + fulfillmentOrder.Id);
            
            // Create Fulfillment Order Product records
            List<Fulfillment_Order_Productt__c> fulfillmentProducts = new List<Fulfillment_Order_Productt__c>();
            Decimal totalQuantity = 0;
            
            for (OrderItem item : orderItems) {
                Fulfillment_Order_Productt__c fulfillmentProduct = new Fulfillment_Order_Productt__c(
                    Name = fulfillmentOrder.Name + ' - ' + item.Product2.Name,
                    Fulfillment_Order__c = fulfillmentOrder.Id,
                    Product__c = item.Product2Id,
                    Account__c = order.AccountId,
                    Order__c = order.Id,                 // Link to original order
                    Order_Product__c = item.Id,          // Link to original order item
                    Quantity__c = item.Quantity,
                    Unit_Price__c = item.UnitPrice,
                    Gross_Unit_Price__c = item.UnitPrice,
                    Line_Subtotal__c = item.TotalPrice,
                    Description__c = item.Product2.Description,
                    Amazon_fulfillment_channel__c = 'MFN'  // Merchant Fulfilled Network
                    // Note: Removed non-writeable fields - they may be formula fields or system-populated:
                    // Created_By__c, Account_Name__c, Address fields, Prefered_Shipping_Date__c
                );
                
                fulfillmentProducts.add(fulfillmentProduct);
                totalQuantity += item.Quantity;
            }
            
            // Insert fulfillment order products
            insert fulfillmentProducts;
            System.debug('✅ Created ' + fulfillmentProducts.size() + ' Fulfillment Order Products');
            
            // Note: Total_Quantity__c is likely a formula field that auto-calculates from child records
            
            // Update the original order's installation type to Self Install
            order.Installation_Type__c = 'Self Install';
            update order;
            System.debug('✅ Updated order installation type to Self Install');
            
            // Create success response
            Map<String, Object> response = new Map<String, Object>{
                'success' => true,
                'message' => 'Order converted to Self Install due to non-serviceable zip code. Fulfillment order created.',
                'installationType' => 'Self Install',
                'conversionReason' => 'Zip code ' + zipCode + ' is not serviceable by technicians',
                'originalInstallationType' => 'Tech Install',
                'fulfillmentOrderId' => fulfillmentOrder.Id,
                'fulfillmentOrderName' => fulfillmentOrder.Name,
                'productsCount' => fulfillmentProducts.size(),
                'totalQuantity' => totalQuantity,
                'zipCode' => zipCode,
                'isZipServiceable' => false,
                'nextSteps' => 'Your products will be shipped to you for self-installation since technician service is not available in your area.',
                'estimatedShipping' => 'Products will be shipped within 3 business days.',
                'shippingAddress' => new Map<String, Object>{
                    'street' => String.isNotBlank(account.ShippingStreet) ? account.ShippingStreet : account.BillingStreet,
                    'city' => String.isNotBlank(account.ShippingCity) ? account.ShippingCity : account.BillingCity,
                    'state' => String.isNotBlank(account.ShippingState) ? account.ShippingState : account.BillingState,
                    'postalCode' => zipCode,
                    'country' => String.isNotBlank(account.ShippingCountry) ? account.ShippingCountry : account.BillingCountry
                },
                'orderStatus' => 'Activated'
            };
            
            System.debug('✅ Fulfillment order creation completed for non-serviceable zip code');
            return JSON.serialize(response);
            
        } catch (Exception e) {
            System.debug('❌ Error creating fulfillment order for non-serviceable zip:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            return createErrorResponse('Failed to create fulfillment order for non-serviceable zip: ' + e.getMessage());
        }
    }
}
