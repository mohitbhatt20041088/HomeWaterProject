// Script to safely delete records from specified objects
// WARNING: This will permanently delete data - use with caution!

System.debug('=== Starting Safe Record Deletion Process ===');

try {
    // Step 1: Check current record counts first
    System.debug('\n=== Current Record Counts ===');
    try { System.debug('Person Accounts: ' + [SELECT COUNT() FROM Account WHERE IsPersonAccount = true]); } catch (Exception e) { System.debug('Person Accounts query failed: ' + e.getMessage()); }
    try { System.debug('Business Accounts: ' + [SELECT COUNT() FROM Account WHERE IsPersonAccount = false]); } catch (Exception e) { System.debug('Business Accounts query failed: ' + e.getMessage()); }
    try { System.debug('Orders: ' + [SELECT COUNT() FROM Order]); } catch (Exception e) { System.debug('Orders query failed: ' + e.getMessage()); }
    try { System.debug('Order Items: ' + [SELECT COUNT() FROM OrderItem]); } catch (Exception e) { System.debug('Order Items query failed: ' + e.getMessage()); }
    try { System.debug('Payment Methods: ' + [SELECT COUNT() FROM PaymentMethod]); } catch (Exception e) { System.debug('Payment Methods query failed: ' + e.getMessage()); }
    try { System.debug('Payments: ' + [SELECT COUNT() FROM Payment]); } catch (Exception e) { System.debug('Payments query failed: ' + e.getMessage()); }
    try { System.debug('Invoices: ' + [SELECT COUNT() FROM Invoice]); } catch (Exception e) { System.debug('Invoices query failed: ' + e.getMessage()); }
    try { System.debug('Invoice Lines: ' + [SELECT COUNT() FROM InvoiceLine]); } catch (Exception e) { System.debug('Invoice Lines query failed: ' + e.getMessage()); }
    
    // Step 2: Delete Order Items first (child records)
    System.debug('\n1. Deleting Order Items...');
    try {
        List<OrderItem> orderItems = [SELECT Id FROM OrderItem LIMIT 10000];
        if (!orderItems.isEmpty()) {
            delete orderItems;
            System.debug('✅ Successfully deleted ' + orderItems.size() + ' Order Items');
        } else {
            System.debug('ℹ️ No Order Items found');
        }
    } catch (Exception e) {
        System.debug('❌ Error with Order Items: ' + e.getMessage());
    }
    
    // Step 3: Delete Orders
    System.debug('\n2. Deleting Orders...');
    try {
        List<Order> orders = [SELECT Id FROM Order LIMIT 10000];
        if (!orders.isEmpty()) {
            delete orders;
            System.debug('✅ Successfully deleted ' + orders.size() + ' Orders');
        } else {
            System.debug('ℹ️ No Orders found');
        }
    } catch (Exception e) {
        System.debug('❌ Error with Orders: ' + e.getMessage());
    }
    
    // Step 4: Delete Payments (before Payment Methods)
    System.debug('\n3. Deleting Payments...');
    try {
        List<Payment> payments = [SELECT Id FROM Payment LIMIT 10000];
        if (!payments.isEmpty()) {
            delete payments;
            System.debug('✅ Successfully deleted ' + payments.size() + ' Payments');
        } else {
            System.debug('ℹ️ No Payments found');
        }
    } catch (Exception e) {
        System.debug('❌ Error with Payments: ' + e.getMessage());
    }
    
    // Step 5: Delete Payment Methods
    System.debug('\n4. Deleting Payment Methods...');
    try {
        List<PaymentMethod> paymentMethods = [SELECT Id FROM PaymentMethod LIMIT 10000];
        if (!paymentMethods.isEmpty()) {
            delete paymentMethods;
            System.debug('✅ Successfully deleted ' + paymentMethods.size() + ' Payment Methods');
        } else {
            System.debug('ℹ️ No Payment Methods found');
        }
    } catch (Exception e) {
        System.debug('❌ Error with Payment Methods: ' + e.getMessage());
    }
    
    // Step 6: Delete Invoices (this should automatically delete Invoice Lines via cascade)
    System.debug('\n5. Deleting Invoices (will cascade to Invoice Lines)...');
    try {
        List<Invoice> invoices = [SELECT Id FROM Invoice LIMIT 10000];
        if (!invoices.isEmpty()) {
            delete invoices;
            System.debug('✅ Successfully deleted ' + invoices.size() + ' Invoices');
        } else {
            System.debug('ℹ️ No Invoices found');
        }
    } catch (Exception e) {
        System.debug('❌ Error with Invoices: ' + e.getMessage());
    }
    
    // Step 7: Delete Person Accounts
    System.debug('\n6. Deleting Person Accounts...');
    try {
        List<Account> personAccounts = [
            SELECT Id, Name, IsPersonAccount 
            FROM Account 
            WHERE IsPersonAccount = true 
            LIMIT 10000
        ];
        
        if (!personAccounts.isEmpty()) {
            System.debug('Found ' + personAccounts.size() + ' Person Accounts to delete');
            for (Integer i = 0; i < Math.min(3, personAccounts.size()); i++) {
                System.debug('  - ' + personAccounts[i].Name);
            }
            try {
                delete personAccounts;
                System.debug('✅ Successfully deleted ' + personAccounts.size() + ' Person Accounts');
            } catch (Exception e) {
                System.debug('❌ Failed to delete Person Accounts: ' + e.getMessage());
            }
        } else {
            System.debug('ℹ️ No Person Accounts found');
        }
    } catch (Exception e) {
        System.debug('❌ Error querying Person Accounts: ' + e.getMessage());
    }
    
    // Step 8: Check Business Accounts (but don't delete by default)
    System.debug('\n7. Checking Business Accounts...');
    try {
        List<Account> businessAccounts = [
            SELECT Id, Name, IsPersonAccount 
            FROM Account 
            WHERE IsPersonAccount = false 
            LIMIT 10000
        ];
        
        if (!businessAccounts.isEmpty()) {
            System.debug('Found ' + businessAccounts.size() + ' Business Accounts');
            System.debug('Sample Business Accounts:');
            for (Integer i = 0; i < Math.min(3, businessAccounts.size()); i++) {
                System.debug('  - ' + businessAccounts[i].Name);
            }
            
            // Uncomment the next lines to delete business accounts too
            // delete businessAccounts;
            // System.debug('✅ Successfully deleted ' + businessAccounts.size() + ' Business Accounts');
            System.debug('ℹ️ Business Accounts preserved (uncomment lines to delete)');
        } else {
            System.debug('ℹ️ No Business Accounts found');
        }
    } catch (Exception e) {
        System.debug('❌ Error querying Business Accounts: ' + e.getMessage());
    }
    
    System.debug('\n=== Deletion Process Completed ===');
    
    // Final count of remaining records
    System.debug('\n=== Final Record Counts ===');
    try { System.debug('Person Accounts remaining: ' + [SELECT COUNT() FROM Account WHERE IsPersonAccount = true]); } catch (Exception e) { System.debug('Person Accounts count failed: ' + e.getMessage()); }
    try { System.debug('Business Accounts remaining: ' + [SELECT COUNT() FROM Account WHERE IsPersonAccount = false]); } catch (Exception e) { System.debug('Business Accounts count failed: ' + e.getMessage()); }
    try { System.debug('Orders remaining: ' + [SELECT COUNT() FROM Order]); } catch (Exception e) { System.debug('Orders count failed: ' + e.getMessage()); }
    try { System.debug('Order Items remaining: ' + [SELECT COUNT() FROM OrderItem]); } catch (Exception e) { System.debug('Order Items count failed: ' + e.getMessage()); }
    try { System.debug('Payment Methods remaining: ' + [SELECT COUNT() FROM PaymentMethod]); } catch (Exception e) { System.debug('Payment Methods count failed: ' + e.getMessage()); }
    try { System.debug('Payments remaining: ' + [SELECT COUNT() FROM Payment]); } catch (Exception e) { System.debug('Payments count failed: ' + e.getMessage()); }
    try { System.debug('Invoices remaining: ' + [SELECT COUNT() FROM Invoice]); } catch (Exception e) { System.debug('Invoices count failed: ' + e.getMessage()); }
    try { System.debug('Invoice Lines remaining: ' + [SELECT COUNT() FROM InvoiceLine]); } catch (Exception e) { System.debug('Invoice Lines count failed: ' + e.getMessage()); }
    
} catch (Exception e) {
    System.debug('❌ CRITICAL ERROR during deletion process:');
    System.debug('  - Type: ' + e.getTypeName());
    System.debug('  - Message: ' + e.getMessage());
    System.debug('  - Line Number: ' + e.getLineNumber());
    System.debug('  - Stack Trace: ' + e.getStackTraceString());
}
