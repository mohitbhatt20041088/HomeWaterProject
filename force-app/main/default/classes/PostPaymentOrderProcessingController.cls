public with sharing class PostPaymentOrderProcessingController {
    
    /**
     * Processes orders after successful payment based on installation type
     * If installation type is 'Self Install', creates Fulfillment Order and Fulfillment Order Line Items
     * If installation type is 'Tech Install', creates Installation Order and Installation Order Products
     */
    @AuraEnabled
    public static String processOrderAfterPayment(String orderId, String invoiceId, String paymentIntentId) {
        System.debug('=== Starting processOrderAfterPayment ===');
        System.debug('Order ID: ' + orderId);
        System.debug('Invoice ID: ' + invoiceId);
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
                result = processSelfInstallOrder(order, invoiceId, paymentIntentId);
            } else if (order.Installation_Type__c == 'Tech Install') {
                System.debug('Processing Tech Install - Creating Installation Order');
                result = processTechInstallOrder(order, invoiceId, paymentIntentId);
            } else {
                return createErrorResponse('Unknown installation type: ' + order.Installation_Type__c + 
                                         '. Expected "Self Install" or "Tech Install"');
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
    private static String processSelfInstallOrder(Order order, String invoiceId, String paymentIntentId) {
        System.debug('=== Processing Self Install Order ===');
        
        try {
            // Create Fulfillment Order
            Fulfillment_Order__c fulfillmentOrder = new Fulfillment_Order__c(
                Name = 'FO-' + order.OrderNumber,
                Account__c = order.AccountId,
                Order_Recipient__c = order.Account.Name,
                Status__c = 'New',
                Delivery_SLA__c = 'Standard'
            );
            
            insert fulfillmentOrder;
            System.debug('Created Fulfillment Order: ' + fulfillmentOrder.Id);
            
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
                        Fulfillment_Order__c = fulfillmentOrder.Id,
                        Product__c = item.Product2Id,
                        Quantity__c = item.Quantity,
                        Unit_Price__c = item.UnitPrice,
                        Gross_Unit_Price__c = item.UnitPrice,
                        Line_Subtotal__c = item.TotalPrice,
                        Order_Product__c = item.Id,
                        Description__c = item.Product2.Description
                    );
                    fulfillmentLineItems.add(lineItem);
                }
                
                insert fulfillmentLineItems;
                System.debug('Created ' + fulfillmentLineItems.size() + ' Fulfillment Order Line Items');
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
    private static String processTechInstallOrder(Order order, String invoiceId, String paymentIntentId) {
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
                Is_Suspended__c = false
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
}
