// Test script to verify payment processing and fulfillment creation
System.debug('=== TESTING PAYMENT PROCESSING AND FULFILLMENT CREATION ===');

// First, let's activate the draft order
String orderId = '801gL00000HFvqfQAD';
System.debug('Testing with Order ID: ' + orderId);

// Get the order details first
List<Order> orders = [SELECT Id, Name, Status, Installation_Type__c, AccountId FROM Order WHERE Id = :orderId LIMIT 1];
if (!orders.isEmpty()) {
    Order order = orders[0];
    System.debug('Order found: ' + order.Name + ' | Status: ' + order.Status + ' | Installation Type: ' + order.Installation_Type__c);
    
    // Activate the order if it's draft
    if (order.Status == 'Draft') {
        order.Status = 'Activated';
        update order;
        System.debug('✅ Order activated: ' + order.Id);
    }
    
    // Now test the fulfillment creation
    try {
        String result = PostPaymentOrderProcessingHelper.processOrderByIdAfterPayment(orderId, 'pi_test_payment_intent_123');
        System.debug('✅ Processing result: ' + result);
        
        // Check if fulfillment records were created
        List<Fulfillment_Order__c> fulfillments = [SELECT Id, Name, Order__c, Fulfillment_Action__c FROM Fulfillment_Order__c WHERE Order__c = :orderId];
        System.debug('📋 Fulfillment records found: ' + fulfillments.size());
        for (Fulfillment_Order__c f : fulfillments) {
            System.debug('  - ' + f.Name + ' | Action: ' + f.Fulfillment_Action__c);
        }
        
    } catch (Exception e) {
        System.debug('❌ Error processing order: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
    }
} else {
    System.debug('❌ Order not found with ID: ' + orderId);
}

System.debug('=== TEST COMPLETED ===');
