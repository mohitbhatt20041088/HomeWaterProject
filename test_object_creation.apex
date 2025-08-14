// Test script to identify the correct API names for Fulfillment and Installation objects

System.debug('=== Testing Object Creation ===');

// Get all SObject types to find our objects
Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

System.debug('\n=== Searching for Fulfillment/Installation Objects ===');
for (String key : globalDescribe.keySet()) {
    if (key.toLowerCase().contains('fulfillment') || key.toLowerCase().contains('installation')) {
        Schema.SObjectType objType = globalDescribe.get(key);
        Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
        System.debug('Found: ' + key + ' | Label: ' + objDescribe.getLabel() + ' | Createable: ' + objDescribe.isCreateable());
    }
}

// Test if we can get a test account
List<Account> testAccounts = [SELECT Id, Name FROM Account LIMIT 1];
if (testAccounts.isEmpty()) {
    System.debug('ERROR: No accounts found for testing');
    return;
}

Account testAccount = testAccounts[0];
System.debug('Using test account: ' + testAccount.Name + ' (ID: ' + testAccount.Id + ')');

// Try to create records with different possible API names
List<String> possibleFulfillmentNames = new List<String>{
    'Fulfillment_Order__c',
    'FulfillmentOrder__c', 
    'Fulfillment_Orders__c',
    'FulfillmentOrders__c'
};

List<String> possibleInstallationNames = new List<String>{
    'Installation_Order__c',
    'InstallationOrder__c',
    'Installation_Orders__c',
    'InstallationOrders__c'
};

System.debug('\n=== Testing Fulfillment Object Creation ===');
for (String objName : possibleFulfillmentNames) {
    try {
        if (globalDescribe.containsKey(objName.toLowerCase())) {
            System.debug('✅ Found object: ' + objName);
            
            // Try to create a test record
            SObject testRecord = globalDescribe.get(objName.toLowerCase()).newSObject();
            testRecord.put('Name', 'TEST-' + System.now().format('HHmmss'));
            testRecord.put('Account__c', testAccount.Id);
            
            insert testRecord;
            System.debug('✅ SUCCESS: Created record with ID: ' + testRecord.Id);
            
            // Clean up
            delete testRecord;
            System.debug('✅ Test record cleaned up');
            break;
        }
    } catch (Exception e) {
        System.debug('❌ Failed to create ' + objName + ': ' + e.getMessage());
    }
}

System.debug('\n=== Testing Installation Object Creation ===');
for (String objName : possibleInstallationNames) {
    try {
        if (globalDescribe.containsKey(objName.toLowerCase())) {
            System.debug('✅ Found object: ' + objName);
            
            // Try to create a test record
            SObject testRecord = globalDescribe.get(objName.toLowerCase()).newSObject();
            testRecord.put('Name', 'TEST-' + System.now().format('HHmmss'));
            testRecord.put('Account__c', testAccount.Id);
            
            insert testRecord;
            System.debug('✅ SUCCESS: Created record with ID: ' + testRecord.Id);
            
            // Clean up
            delete testRecord;
            System.debug('✅ Test record cleaned up');
            break;
        }
    } catch (Exception e) {
        System.debug('❌ Failed to create ' + objName + ': ' + e.getMessage());
    }
}
