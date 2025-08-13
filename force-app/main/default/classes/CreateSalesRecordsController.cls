public with sharing class CreateSalesRecordsController {
    
    @AuraEnabled(cacheable=true)
    public static List<Product2> getActiveProducts() {
        try {
            return [
                SELECT Id, Name, ProductCode, Family, Description, IsActive
                FROM Product2 
                WHERE IsActive = true 
                ORDER BY Name ASC 
                LIMIT 1000
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving products: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String createFullOrder(OrderRequest request) {
        try {
            System.debug('=== Starting createFullOrder ===');
            System.debug('Request: ' + JSON.serialize(request));
            
            // Start transaction
            Savepoint sp = Database.setSavepoint();
            
            // 1. First create Order and Order Line Items with temporary account
            System.debug('Creating order and line items first...');
            String orderId = createOrderAndLineItemsFirst(request.selectedProductIds);
            System.debug('Order and line items created successfully with ID: ' + orderId);
            
            // 2. Only after successful order creation, create Account
            System.debug('Creating/finding account...');
            Account acc = createOrFindAccount(request);
            System.debug('Account created/found: ' + acc.Id);
            
            // 3. Create Opportunity
            System.debug('Creating opportunity...');
            Opportunity opp = createOpportunity(acc.Id, request);
            System.debug('Opportunity created: ' + opp.Id);
            
            // 4. Update the Order to link it to the Account and Opportunity
            System.debug('Updating order to link with Account and Opportunity...');
            updateOrderWithAccountAndOpportunity(orderId, acc.Id, opp.Id);
            System.debug('Order updated successfully');
            
            System.debug('=== Finished createFullOrder ===');
            return opp.Id;
            
        } catch (Exception e) {
            System.debug('ERROR in createFullOrder: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error creating records: ' + e.getMessage());
        }
    }
    
    private static Account createOrFindAccount(OrderRequest request) {
        String accountName = request.firstName + ' ' + request.lastName;
        
        // Check if Person Accounts are enabled
        List<RecordType> personAccountRTs = [
            SELECT Id 
            FROM RecordType 
            WHERE SObjectType = 'Account' 
            AND IsPersonType = true 
            LIMIT 1
        ];
        
        Boolean isPersonAccountEnabled = !personAccountRTs.isEmpty();
        
        // Check if account already exists
        List<Account> existingAccounts;
        
        if (isPersonAccountEnabled) {
            existingAccounts = [
                SELECT Id, Name 
                FROM Account 
                WHERE PersonEmail = :request.email 
                LIMIT 1
            ];
        } else {
            existingAccounts = [
                SELECT Id, Name 
                FROM Account 
                WHERE Name = :accountName 
                LIMIT 1
            ];
        }
        
        if (!existingAccounts.isEmpty()) {
            return existingAccounts[0];
        }
        
        // Create new account
        Account newAccount = new Account();
        
        if (isPersonAccountEnabled) {
            // Create Person Account
            newAccount.RecordTypeId = personAccountRTs[0].Id;
            newAccount.FirstName = request.firstName;
            newAccount.LastName = request.lastName;
            newAccount.PersonEmail = request.email;
            newAccount.Phone = request.phone;
            newAccount.BillingStreet = request.address;
        } else {
            // Create Business Account
            newAccount.Name = accountName;
            newAccount.Phone = request.phone;
            newAccount.BillingStreet = request.address;
            // Note: Email cannot be directly stored on Business Account
            // You might need to create a Contact for email storage
        }
        
        newAccount.Type = 'Customer - Direct';
        
        insert newAccount;
        
        // If Business Account and email provided, create a Contact
        if (!isPersonAccountEnabled && String.isNotBlank(request.email)) {
            Contact contact = new Contact(
                FirstName = request.firstName,
                LastName = request.lastName,
                Email = request.email,
                Phone = request.phone,
                AccountId = newAccount.Id
            );
            insert contact;
        }
        
        return newAccount;
    }
    
    private static Opportunity createOpportunity(Id accountId, OrderRequest request) {
        // Generate opportunity name based on customer name and date
        String oppName = request.firstName + ' ' + request.lastName + ' - Order ' + Date.today().format();
        
        Opportunity opp = new Opportunity(
            Name = oppName,
            AccountId = accountId,
            CloseDate = Date.today().addDays(30), // Default to 30 days from now
            StageName = 'Prospecting', // Default stage
            Amount = 0 // Will be updated when products are added
        );
        insert opp;
        return opp;
    }
    
    private static String createOrderAndLineItemsFirst(List<String> productIds) {
        System.debug('createOrderAndLineItemsFirst called with productIds: ' + productIds);
        
        if (productIds == null || productIds.isEmpty()) {
            System.debug('No product IDs provided, creating order without line items');
            // Still create the order even without products
            return createEmptyOrderFirst();
        }
        
        System.debug('Creating order with product IDs: ' + productIds);
        
        // Get standard price book
        Id standardPricebookId;
        if (Test.isRunningTest()) {
            standardPricebookId = Test.getStandardPricebookId();
        } else {
            List<Pricebook2> standardPricebooks = [
                SELECT Id 
                FROM Pricebook2 
                WHERE IsStandard = true 
                LIMIT 1
            ];
            if (standardPricebooks.isEmpty()) {
                throw new AuraHandledException('No standard price book found in the system.');
            }
            standardPricebookId = standardPricebooks[0].Id;
        }
        
        System.debug('Using standard price book: ' + standardPricebookId);
        
        // Create a temporary account for the order (will be updated later)
        Account tempAccount = new Account(
            Name = 'TEMP_ORDER_ACCOUNT_' + System.now().getTime(),
            Type = 'Other'
        );
        insert tempAccount;
        System.debug('Created temporary account: ' + tempAccount.Id);
        
        // Create Order with temporary account
        Order newOrder = new Order(
            AccountId = tempAccount.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = standardPricebookId
        );
        insert newOrder;
        System.debug('Created order: ' + newOrder.Id);
        
        // Get products and their price book entries
        List<PricebookEntry> priceEntries = [
            SELECT Id, Product2Id, UnitPrice 
            FROM PricebookEntry 
            WHERE Product2Id IN :productIds 
            AND Pricebook2Id = :standardPricebookId
            AND IsActive = true
        ];
        
        System.debug('Found price entries: ' + priceEntries.size());
        
        if (priceEntries.isEmpty()) {
            System.debug('No price book entries found for these products. IDs: ' + productIds);
            System.debug('Attempting to create missing price book entries...');
            
            // Try to create missing price book entries
            createMissingPricebookEntries(productIds, standardPricebookId);
            
            // Query again for price entries
            priceEntries = [
                SELECT Id, Product2Id, UnitPrice 
                FROM PricebookEntry 
                WHERE Product2Id IN :productIds 
                AND Pricebook2Id = :standardPricebookId
                AND IsActive = true
            ];
            
            System.debug('After creating entries, found price entries: ' + priceEntries.size());
            
            if (priceEntries.isEmpty()) {
                // Clean up temporary account
                delete tempAccount;
                throw new AuraHandledException('Unable to create price book entries for the selected products. Please contact your administrator.');
            }
        }
        
        // Create Order Line Items
        List<OrderItem> orderLineItems = new List<OrderItem>();
        
        for (PricebookEntry entry : priceEntries) {
            OrderItem lineItem = new OrderItem(
                OrderId = newOrder.Id,
                PricebookEntryId = entry.Id,
                Quantity = 1,
                UnitPrice = entry.UnitPrice
            );
            orderLineItems.add(lineItem);
        }
        
        if (!orderLineItems.isEmpty()) {
            insert orderLineItems;
            System.debug('Created ' + orderLineItems.size() + ' order line items');
        }
        
        return newOrder.Id;
    }
    
    private static String createEmptyOrderFirst() {
        // Get standard price book
        Id standardPricebookId;
        if (Test.isRunningTest()) {
            standardPricebookId = Test.getStandardPricebookId();
        } else {
            List<Pricebook2> standardPricebooks = [
                SELECT Id 
                FROM Pricebook2 
                WHERE IsStandard = true 
                LIMIT 1
            ];
            if (standardPricebooks.isEmpty()) {
                throw new AuraHandledException('No standard price book found in the system.');
            }
            standardPricebookId = standardPricebooks[0].Id;
        }
        
        // Create a temporary account for the order (will be updated later)
        Account tempAccount = new Account(
            Name = 'TEMP_ORDER_ACCOUNT_' + System.now().getTime(),
            Type = 'Other'
        );
        insert tempAccount;
        System.debug('Created temporary account: ' + tempAccount.Id);
        
        // Create Order without line items
        Order newOrder = new Order(
            AccountId = tempAccount.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = standardPricebookId
        );
        insert newOrder;
        System.debug('Created empty order: ' + newOrder.Id);
        
        return newOrder.Id;
    }
    
    private static void updateOrderWithAccountAndOpportunity(String orderId, Id accountId, Id opportunityId) {
        System.debug('Updating order ' + orderId + ' with account ' + accountId + ' and opportunity ' + opportunityId);
        
        // Get the order and its temporary account
        Order orderToUpdate = [
            SELECT Id, AccountId
            FROM Order 
            WHERE Id = :orderId
            LIMIT 1
        ];
        
        Id tempAccountId = orderToUpdate.AccountId;
        
        // Update the order with real account and opportunity
        orderToUpdate.AccountId = accountId;
        orderToUpdate.OpportunityId = opportunityId;
        update orderToUpdate;
        
        System.debug('Order updated successfully');
        
        // Clean up temporary account
        try {
            Account tempAccount = new Account(Id = tempAccountId);
            delete tempAccount;
            System.debug('Temporary account deleted: ' + tempAccountId);
        } catch (Exception e) {
            System.debug('Could not delete temporary account: ' + e.getMessage());
            // Don't fail the whole process if we can't clean up temp account
        }
    }
    
    private static void createMissingPricebookEntries(List<String> productIds, Id standardPricebookId) {
        try {
            System.debug('Creating missing pricebook entries for products: ' + productIds);
            
            // Get products that exist
            List<Product2> products = [
                SELECT Id, Name
                FROM Product2
                WHERE Id IN :productIds
                AND IsActive = true
            ];
            
            System.debug('Found ' + products.size() + ' active products');
            
            if (products.isEmpty()) {
                System.debug('No active products found for the given IDs');
                return;
            }
            
            // Create price book entries for products that don't have them
            List<PricebookEntry> newEntries = new List<PricebookEntry>();
            
            for (Product2 product : products) {
                PricebookEntry entry = new PricebookEntry(
                    Pricebook2Id = standardPricebookId,
                    Product2Id = product.Id,
                    UnitPrice = 100.00, // Default price - you can modify this
                    IsActive = true
                );
                newEntries.add(entry);
            }
            
            if (!newEntries.isEmpty()) {
                insert newEntries;
                System.debug('Created ' + newEntries.size() + ' new price book entries');
            }
            
        } catch (Exception e) {
            System.debug('Error creating price book entries: ' + e.getMessage());
            // Don't throw exception here, let the calling method handle it
        }
    }
    
    // Wrapper class for request data
    public class OrderRequest {
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String address { get; set; }
        @AuraEnabled public List<String> selectedProductIds { get; set; }
    }
}