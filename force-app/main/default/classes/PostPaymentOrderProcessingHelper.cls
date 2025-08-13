public with sharing class PostPaymentOrderProcessingHelper {
    
    /**
     * Alternative method to process orders by orderId directly (useful for testing/manual processing)
     */
    @AuraEnabled
    public static String processOrderByIdAfterPayment(String orderId, String paymentIntentId) {
        System.debug('=== Processing Order By ID After Payment ===');
        System.debug('Order ID: ' + orderId);
        System.debug('Payment Intent ID: ' + paymentIntentId);
        
        try {
            if (String.isBlank(orderId)) {
                return createErrorResponse('Order ID is required');
            }
            
            if (String.isBlank(paymentIntentId)) {
                return createErrorResponse('Payment Intent ID is required');
            }
            
            // Call the main processing method
            String result = PostPaymentOrderProcessingController.processOrderAfterPayment(orderId, null, paymentIntentId);
            
            return result;
            
        } catch (Exception e) {
            System.debug('EXCEPTION in processOrderByIdAfterPayment:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            return createErrorResponse('Failed to process order by ID: ' + e.getMessage());
        }
    }
    
    /**
     * Method to find and process any pending orders for an account after payment
     */
    @AuraEnabled
    public static String processPendingOrdersForAccount(String accountId, String paymentIntentId) {
        System.debug('=== Processing Pending Orders for Account ===');
        System.debug('Account ID: ' + accountId);
        System.debug('Payment Intent ID: ' + paymentIntentId);
        
        try {
            if (String.isBlank(accountId)) {
                return createErrorResponse('Account ID is required');
            }
            
            // Find all pending orders for this account
            List<Order> pendingOrders = [
                SELECT Id, OrderNumber, Installation_Type__c, AccountId, Status, TotalAmount
                FROM Order 
                WHERE AccountId = :accountId
                AND Status = 'Draft'
                AND Installation_Type__c != null
                ORDER BY CreatedDate DESC
            ];
            
            if (pendingOrders.isEmpty()) {
                Map<String, Object> response = new Map<String, Object>{
                    'success' => true,
                    'message' => 'No pending orders found for this account',
                    'accountId' => accountId,
                    'ordersProcessed' => 0
                };
                return JSON.serialize(response);
            }
            
            System.debug('Found ' + pendingOrders.size() + ' pending orders to process');
            
            List<Map<String, Object>> processedOrders = new List<Map<String, Object>>();
            Integer successCount = 0;
            Integer errorCount = 0;
            
            // Process each order
            for (Order order : pendingOrders) {
                try {
                    String orderResult = PostPaymentOrderProcessingController.processOrderAfterPayment(
                        order.Id, 
                        null, 
                        paymentIntentId
                    );
                    
                    Map<String, Object> orderResultData = (Map<String, Object>) JSON.deserializeUntyped(orderResult);
                    
                    if (orderResultData.get('success') == true) {
                        successCount++;
                        processedOrders.add(new Map<String, Object>{
                            'orderId' => order.Id,
                            'orderNumber' => order.OrderNumber,
                            'installationType' => order.Installation_Type__c,
                            'status' => 'Success',
                            'result' => orderResultData
                        });
                    } else {
                        errorCount++;
                        processedOrders.add(new Map<String, Object>{
                            'orderId' => order.Id,
                            'orderNumber' => order.OrderNumber,
                            'installationType' => order.Installation_Type__c,
                            'status' => 'Error',
                            'error' => orderResultData.get('message')
                        });
                    }
                    
                } catch (Exception orderEx) {
                    errorCount++;
                    System.debug('Error processing order ' + order.Id + ': ' + orderEx.getMessage());
                    processedOrders.add(new Map<String, Object>{
                        'orderId' => order.Id,
                        'orderNumber' => order.OrderNumber,
                        'installationType' => order.Installation_Type__c,
                        'status' => 'Error',
                        'error' => orderEx.getMessage()
                    });
                }
            }
            
            Map<String, Object> response = new Map<String, Object>{
                'success' => true,
                'message' => 'Processed ' + pendingOrders.size() + ' orders (' + successCount + ' successful, ' + errorCount + ' errors)',
                'accountId' => accountId,
                'totalOrders' => pendingOrders.size(),
                'successCount' => successCount,
                'errorCount' => errorCount,
                'processedOrders' => processedOrders
            };
            
            return JSON.serialize(response);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in processPendingOrdersForAccount:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            return createErrorResponse('Failed to process pending orders for account: ' + e.getMessage());
        }
    }
    
    /**
     * Method to get all orders with installation types (for debugging/monitoring)
     */
    @AuraEnabled(cacheable=true)
    public static String getOrdersWithInstallationTypes(Integer limitCount) {
        System.debug('=== Getting Orders with Installation Types ===');
        
        try {
            if (limitCount == null || limitCount <= 0) {
                limitCount = 10;
            }
            
            List<Order> orders = [
                SELECT Id, OrderNumber, Installation_Type__c, AccountId, Account.Name,
                       Status, TotalAmount, EffectiveDate, CreatedDate,
                       (SELECT Id, Product2.Name, Quantity FROM OrderItems)
                FROM Order 
                WHERE Installation_Type__c != null
                ORDER BY CreatedDate DESC
                LIMIT :limitCount
            ];
            
            List<Map<String, Object>> orderData = new List<Map<String, Object>>();
            
            for (Order order : orders) {
                Map<String, Object> orderInfo = new Map<String, Object>{
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
                };
                orderData.add(orderInfo);
            }
            
            Map<String, Object> response = new Map<String, Object>{
                'success' => true,
                'orders' => orderData,
                'totalFound' => orders.size(),
                'message' => 'Found ' + orders.size() + ' orders with installation types'
            };
            
            return JSON.serialize(response);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in getOrdersWithInstallationTypes:');
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            return createErrorResponse('Failed to get orders with installation types: ' + e.getMessage());
        }
    }
    
    /**
     * Method to check if fulfillment/installation orders were created for a given source order
     */
    @AuraEnabled(cacheable=true)
    public static String checkOrderProcessingStatus(String sourceOrderId) {
        System.debug('=== Checking Order Processing Status ===');
        System.debug('Source Order ID: ' + sourceOrderId);
        
        try {
            if (String.isBlank(sourceOrderId)) {
                return createErrorResponse('Source Order ID is required');
            }
            
            // Get the source order details
            List<Order> sourceOrders = [
                SELECT Id, OrderNumber, Installation_Type__c, Status, AccountId, Account.Name
                FROM Order 
                WHERE Id = :sourceOrderId 
                LIMIT 1
            ];
            
            if (sourceOrders.isEmpty()) {
                return createErrorResponse('Order not found with ID: ' + sourceOrderId);
            }
            
            Order sourceOrder = sourceOrders[0];
            Map<String, Object> response = new Map<String, Object>{
                'success' => true,
                'sourceOrder' => new Map<String, Object>{
                    'id' => sourceOrder.Id,
                    'orderNumber' => sourceOrder.OrderNumber,
                    'installationType' => sourceOrder.Installation_Type__c,
                    'status' => sourceOrder.Status,
                    'accountId' => sourceOrder.AccountId,
                    'accountName' => sourceOrder.Account.Name
                }
            };
            
            // Check for related fulfillment orders (if installation type is Self Install)
            if (sourceOrder.Installation_Type__c == 'Self Install') {
                // Check for fulfillment orders by matching name pattern (since we don't have Source_Order_Id__c available)
                List<Fulfillment_Order__c> fulfillmentOrders = [
                    SELECT Id, Name, Status__c, CreatedDate
                    FROM Fulfillment_Order__c 
                    WHERE Name LIKE :('FO-' + sourceOrder.OrderNumber + '%')
                ];
                
                response.put('fulfillmentOrdersFound', fulfillmentOrders.size());
                if (!fulfillmentOrders.isEmpty()) {
                    List<Map<String, Object>> foData = new List<Map<String, Object>>();
                    for (Fulfillment_Order__c fo : fulfillmentOrders) {
                        foData.add(new Map<String, Object>{
                            'id' => fo.Id,
                            'name' => fo.Name,
                            'status' => fo.Status__c,
                            'createdDate' => fo.CreatedDate
                        });
                    }
                    response.put('fulfillmentOrders', foData);
                }
            }
            
            // Check for related installation orders (if installation type is Tech Install)
            if (sourceOrder.Installation_Type__c == 'Tech Install') {
                // Check for installation orders by matching name pattern
                List<Installation_Order__c> installationOrders = [
                    SELECT Id, Name, Status__c, Total_Amount__c, Created_Date__c, Installation_Order_Number__c
                    FROM Installation_Order__c 
                    WHERE Name LIKE :('IO-' + sourceOrder.OrderNumber + '%')
                ];
                
                response.put('installationOrdersFound', installationOrders.size());
                if (!installationOrders.isEmpty()) {
                    List<Map<String, Object>> ioData = new List<Map<String, Object>>();
                    for (Installation_Order__c io : installationOrders) {
                        ioData.add(new Map<String, Object>{
                            'id' => io.Id,
                            'name' => io.Name,
                            'orderNumber' => io.Installation_Order_Number__c,
                            'status' => io.Status__c,
                            'totalAmount' => io.Total_Amount__c,
                            'createdDate' => io.Created_Date__c
                        });
                    }
                    response.put('installationOrders', ioData);
                }
            }
            
            // Determine overall processing status
            Boolean isProcessed = false;
            String processingMessage = '';
            
            if (sourceOrder.Installation_Type__c == 'Self Install') {
                Integer foCount = (Integer) response.get('fulfillmentOrdersFound');
                isProcessed = (foCount > 0);
                processingMessage = isProcessed ? 
                    'Order has been processed - ' + foCount + ' fulfillment order(s) created' :
                    'Order has not been processed - no fulfillment orders found';
            } else if (sourceOrder.Installation_Type__c == 'Tech Install') {
                Integer ioCount = (Integer) response.get('installationOrdersFound');
                isProcessed = (ioCount > 0);
                processingMessage = isProcessed ? 
                    'Order has been processed - ' + ioCount + ' installation order(s) created' :
                    'Order has not been processed - no installation orders found';
            } else {
                processingMessage = 'Order has no installation type set';
            }
            
            response.put('isProcessed', isProcessed);
            response.put('processingMessage', processingMessage);
            
            return JSON.serialize(response);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in checkOrderProcessingStatus:');
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            return createErrorResponse('Failed to check order processing status: ' + e.getMessage());
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
}
