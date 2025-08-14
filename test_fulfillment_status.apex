// Test script to verify that Fulfillment_Order__c.Status__c accepts 'Draft' as a valid value

try {
    // First, let's get the valid picklist values for Status__c
    Schema.SObjectType sobjectType = Schema.getGlobalDescribe().get('Fulfillment_Order__c');
    Schema.DescribeSObjectResult sobjectDescribe = sobjectType.getDescribe();
    Schema.DescribeFieldResult fieldDescribe = sobjectDescribe.fields.getMap().get('Status__c').getDescribe();
    
    List<Schema.PicklistEntry> picklistValues = fieldDescribe.getPicklistValues();
    System.debug('=== Valid Status__c picklist values ===');
    for (Schema.PicklistEntry entry : picklistValues) {
        System.debug('Value: ' + entry.getValue() + ' | Label: ' + entry.getLabel() + ' | Active: ' + entry.isActive());
    }
    
    // Test creating a Fulfillment Order with Status__c = 'Draft'
    System.debug('\n=== Testing Fulfillment Order creation with Status__c = "Draft" ===');
    
    // Get a test account
    List<Account> testAccounts = [SELECT Id, Name FROM Account LIMIT 1];
    if (testAccounts.isEmpty()) {
        System.debug('ERROR: No accounts found for testing');
        return;
    }
    
    Account testAccount = testAccounts[0];
    System.debug('Using test account: ' + testAccount.Name + ' (ID: ' + testAccount.Id + ')');
    
    // Create test fulfillment order with Status__c = 'Draft'
    Fulfillment_Order__c testFulfillmentOrder = new Fulfillment_Order__c(
        Name = 'TEST-FO-' + System.now().format('yyyyMMdd-HHmmss'),
        Account__c = testAccount.Id,
        Order_Recipient__c = testAccount.Name,
        Status__c = 'Draft',  // This should work now based on our picklist check
        Delivery_SLA__c = 'Standard'
    );
    
    // Try to insert it
    insert testFulfillmentOrder;
    System.debug('✅ SUCCESS: Created Fulfillment Order with Status__c = "Draft"');
    System.debug('Fulfillment Order ID: ' + testFulfillmentOrder.Id);
    System.debug('Fulfillment Order Name: ' + testFulfillmentOrder.Name);
    
    // Clean up - delete the test record
    delete testFulfillmentOrder;
    System.debug('✅ Test record cleaned up');
    
} catch (Exception e) {
    System.debug('❌ ERROR: ' + e.getMessage());
    System.debug('Error Type: ' + e.getTypeName());
    System.debug('Line Number: ' + e.getLineNumber());
    System.debug('Stack Trace: ' + e.getStackTraceString());
}
