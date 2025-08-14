// Script to delete all records from specified objects
// WARNING: This will permanently delete data - use with caution!

System.debug('=== Starting Record Deletion Process ===');

try {
    // Step 1: Delete Invoice Lines (child records first)
    System.debug('\n1. Deleting Invoice Lines...');
    List<InvoiceLine> invoiceLines = [SELECT Id FROM InvoiceLine LIMIT 10000];
    if (!invoiceLines.isEmpty()) {
        delete invoiceLines;
        System.debug('✅ Deleted ' + invoiceLines.size() + ' Invoice Lines');
    } else {
        System.debug('ℹ️ No Invoice Lines found');
    }
    
    // Step 2: Delete Invoices
    System.debug('\n2. Deleting Invoices...');
    List<Invoice> invoices = [SELECT Id FROM Invoice LIMIT 10000];
    if (!invoices.isEmpty()) {
        delete invoices;
        System.debug('✅ Deleted ' + invoices.size() + ' Invoices');
    } else {
        System.debug('ℹ️ No Invoices found');
    }
    
    // Step 3: Delete Payments
    System.debug('\n3. Deleting Payments...');
    List<Payment> payments = [SELECT Id FROM Payment LIMIT 10000];
    if (!payments.isEmpty()) {
        delete payments;
        System.debug('✅ Deleted ' + payments.size() + ' Payments');
    } else {
        System.debug('ℹ️ No Payments found');
    }
    
    // Step 4: Delete Payment Methods
    System.debug('\n4. Deleting Payment Methods...');
    List<PaymentMethod> paymentMethods = [SELECT Id FROM PaymentMethod LIMIT 10000];
    if (!paymentMethods.isEmpty()) {
        delete paymentMethods;
        System.debug('✅ Deleted ' + paymentMethods.size() + ' Payment Methods');
    } else {
        System.debug('ℹ️ No Payment Methods found');
    }
    
    // Step 5: Delete Order Items (Order Line Items)
    System.debug('\n5. Deleting Order Items (Order Line Items)...');
    List<OrderItem> orderItems = [SELECT Id FROM OrderItem LIMIT 10000];
    if (!orderItems.isEmpty()) {
        delete orderItems;
        System.debug('✅ Deleted ' + orderItems.size() + ' Order Items');
    } else {
        System.debug('ℹ️ No Order Items found');
    }
    
    // Step 6: Delete Orders
    System.debug('\n6. Deleting Orders...');
    List<Order> orders = [SELECT Id FROM Order LIMIT 10000];
    if (!orders.isEmpty()) {
        delete orders;
        System.debug('✅ Deleted ' + orders.size() + ' Orders');
    } else {
        System.debug('ℹ️ No Orders found');
    }
    
    // Step 7: Delete Person Accounts (including Business Accounts that might be related)
    System.debug('\n7. Deleting Person Accounts...');
    
    // First, get all Person Accounts
    List<Account> personAccounts = [
        SELECT Id, Name, IsPersonAccount 
        FROM Account 
        WHERE IsPersonAccount = true 
        LIMIT 10000
    ];
    
    if (!personAccounts.isEmpty()) {
        System.debug('Found ' + personAccounts.size() + ' Person Accounts to delete');
        delete personAccounts;
        System.debug('✅ Deleted ' + personAccounts.size() + ' Person Accounts');
    } else {
        System.debug('ℹ️ No Person Accounts found');
    }
    
    // Also delete any remaining Business Accounts if needed
    System.debug('\n8. Checking for remaining Business Accounts...');
    List<Account> businessAccounts = [
        SELECT Id, Name, IsPersonAccount 
        FROM Account 
        WHERE IsPersonAccount = false 
        LIMIT 10000
    ];
    
    if (!businessAccounts.isEmpty()) {
        System.debug('Found ' + businessAccounts.size() + ' Business Accounts');
        System.debug('First few: ');
        for (Integer i = 0; i < Math.min(5, businessAccounts.size()); i++) {
            System.debug('  - ' + businessAccounts[i].Name);
        }
        
        // Uncomment the next lines if you want to delete business accounts too
        // delete businessAccounts;
        // System.debug('✅ Deleted ' + businessAccounts.size() + ' Business Accounts');
        
        System.debug('ℹ️ Business Accounts NOT deleted (uncomment lines in script if needed)');
    } else {
        System.debug('ℹ️ No Business Accounts found');
    }
    
    System.debug('\n=== Record Deletion Process Completed Successfully ===');
    
    // Summary count of remaining records
    System.debug('\n=== Final Record Counts ===');
    System.debug('Person Accounts remaining: ' + [SELECT COUNT() FROM Account WHERE IsPersonAccount = true]);
    System.debug('Business Accounts remaining: ' + [SELECT COUNT() FROM Account WHERE IsPersonAccount = false]);
    System.debug('Orders remaining: ' + [SELECT COUNT() FROM Order]);
    System.debug('Order Items remaining: ' + [SELECT COUNT() FROM OrderItem]);
    System.debug('Payment Methods remaining: ' + [SELECT COUNT() FROM PaymentMethod]);
    System.debug('Payments remaining: ' + [SELECT COUNT() FROM Payment]);
    System.debug('Invoices remaining: ' + [SELECT COUNT() FROM Invoice]);
    System.debug('Invoice Lines remaining: ' + [SELECT COUNT() FROM InvoiceLine]);
    
} catch (Exception e) {
    System.debug('❌ ERROR during deletion process:');
    System.debug('  - Type: ' + e.getTypeName());
    System.debug('  - Message: ' + e.getMessage());
    System.debug('  - Line Number: ' + e.getLineNumber());
    System.debug('  - Stack Trace: ' + e.getStackTraceString());
}
