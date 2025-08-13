public with sharing class StripeIntentController {
    // Using Custom Metadata to store Stripe API keys securely

    private static Strip_Api_Key__mdt stripeConfig {
        get {
            if (stripeConfig == null) {
                stripeConfig = Strip_Api_Key__mdt.getInstance('Stripe_Credential_mdt');
            }
            return stripeConfig;
        }
        set;
    }
    
    // Get Stripe Secret Key from Custom Metadata
    public static String getStripeSecretKey() {
        if (stripeConfig != null && stripeConfig.Secret_Key_Api__c != null) {
            return stripeConfig.Secret_Key_Api__c;
        }
        throw new AuraHandledException('Stripe Secret Key not configured in Custom Metadata');
    }
    
    // Get Stripe Publishable Key from Custom Metadata
    @RemoteAction
    public static String getStripePublishableKey() {
        if (stripeConfig != null && stripeConfig.Publish_key_Api__c != null) {
            return stripeConfig.Publish_key_Api__c;
        }
        throw new AuraHandledException('Stripe Publishable Key not configured in Custom Metadata');
    }
    
    // Include trailing slash for clean concatenation
    public static final String BASE_URL = 'https://api.stripe.com/v1/';
    
    // Method to validate API key format
    private static Boolean isValidStripeKey(String key) {
        return key != null && 
               (key.startsWith('sk_test_') || key.startsWith('sk_live_')) && 
               key.length() >= 32;
    }
    
    @RemoteAction
    public static String createPaymentIntent(Integer amountCents,
                                             String currencyY, String description, String receiptEmail){
        System.debug('=== PaymentIntent Creation Started ===');
        System.debug('Input Parameters:');
        System.debug('  - amountCents: ' + amountCents);
        System.debug('  - currencyY: ' + currencyY);
        System.debug('  - description: ' + description);
        System.debug('  - receiptEmail: ' + receiptEmail);

        try{
            if(amountCents == null || amountCents <= 0){
                System.debug('ERROR: Invalid amount provided: ' + amountCents);
                return errorJson('Invalid Amount');
            }
            if(String.isBlank(currencyY)){
                currencyY = 'usd';
                System.debug('Currency defaulted to USD');
            }

            String secretKey = getStripeSecretKey();
            HttpRequest req = new HttpRequest();
            String endpoint = BASE_URL + 'payment_intents';
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + secretKey);
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            System.debug('Endpoint: ' + endpoint);
            System.debug('Method: POST');
            System.debug('Authorization: Bearer ' + secretKey.substring(0, 12) + '...');

            // Correct parameter names
            String body = 'amount=' + amountCents +
                          '&currency=' + EncodingUtil.urlEncode(currencyY, 'UTF-8') +
                          '&automatic_payment_methods[enabled]=true';
            if(!String.isBlank(description)){
                body+='&description=' + EncodingUtil.urlEncode(description, 'UTF-8');
            }
            if(!String.isBlank(receiptEmail)){
                body+='&receipt_email='+EncodingUtil.urlEncode(receiptEmail, 'UTF-8');
            }
            req.setBody(body);
            System.debug('Request Body: ' + body);

            Http http = new Http();
            System.debug('Sending HTTP request to Stripe...');
            HttpResponse res = http.send(req);
            
            System.debug('Response Status: ' + res.getStatusCode());
            System.debug('Response Status Text: ' + res.getStatus());
            System.debug('Response Body: ' + res.getBody());
            System.debug('=== PaymentIntent Creation Completed ===');
            
            return res.getBody();
        }catch(Exception e){
            System.debug('EXCEPTION in createPaymentIntent:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('PaymentIntent creation failed: '+e.getMessage());
        }
    }

    @RemoteAction
    public static String createSetupIntent(String customerId){
        System.debug('=== SetupIntent Creation Started ===');
        System.debug('Input Parameters:');
        System.debug('  - customerId: ' + customerId);
        
        try{
            String secretKey = getStripeSecretKey();
            HttpRequest req = new HttpRequest();
            String endpoint = BASE_URL + 'setup_intents';
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + secretKey);
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            
            System.debug('Endpoint: ' + endpoint);
            System.debug('Method: POST');
            System.debug('Authorization: Bearer ' + secretKey.substring(0, 12) + '...');
            System.debug('Content-Type: application/x-www-form-urlencoded');

            // Setup Intent requires payment method types or automatic payment methods
            String body = 'automatic_payment_methods[enabled]=true';
            if(!String.isBlank(customerId)){
                body += '&customer=' + EncodingUtil.urlEncode(customerId, 'UTF-8');
                System.debug('Customer ID provided, adding to request body');
            } else {
                System.debug('No customer ID provided, creating setup intent without customer');
            }

            req.setBody(body);
            System.debug('Request Body: ' + body);

            Http http = new Http();
            System.debug('Sending HTTP request to Stripe for SetupIntent...');
            HttpResponse res = http.send(req);
            
            System.debug('SetupIntent Response Status: ' + res.getStatusCode());
            System.debug('SetupIntent Response Status Text: ' + res.getStatus());
            System.debug('SetupIntent Response Body: ' + res.getBody());
            
            // Additional validation of response
            if(res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                System.debug('✅ SetupIntent API call successful');
                try {
                    Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    if(responseData.containsKey('client_secret')) {
                        System.debug('✅ client_secret found in response');
                    } else {
                        System.debug('❌ client_secret NOT found in response');
                        System.debug('Available keys: ' + responseData.keySet());
                    }
                } catch(Exception parseEx) {
                    System.debug('❌ Error parsing response JSON: ' + parseEx.getMessage());
                }
            } else {
                System.debug('❌ SetupIntent API call failed with status: ' + res.getStatusCode());
            }
            
            System.debug('=== SetupIntent Creation Completed ===');
            return res.getBody();
        }catch(Exception e){
            System.debug('EXCEPTION in createSetupIntent:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            System.debug('=== SetupIntent Creation Failed ===');
            return errorJson('SetupIntent creation failed: ' + e.getMessage());
        }
    }

    private static String errorJson(String message){
        System.debug('=== Error Response Created ===');
        System.debug('Error Message: ' + message);
        
        Map<String,Object> m = new Map<String,Object>();
        m.put('error', true);
        m.put('message',message);
        m.put('timestamp', System.now());
        
        String errorResponse = JSON.serialize(m);
        System.debug('Error Response JSON: ' + errorResponse);
        System.debug('=== Error Response Completed ===');
        
        return errorResponse;
    }
    
    // DEBUG HELPER METHODS - Use these for manual testing
    @RemoteAction
    public static String debugPaymentIntent() {
        System.debug('=== DEBUG: Testing PaymentIntent ===');
        return createPaymentIntent(2000, 'usd', 'Debug Test Payment', 'test@example.com');
    }
    
    @RemoteAction
    public static String debugSetupIntent() {
        System.debug('=== DEBUG: Testing SetupIntent ===');
        return createSetupIntent(null);
    }
    
    @RemoteAction
    public static String testStripeConnection() {
        System.debug('=== Testing Stripe API Connection ===');
        
        try {
            String secretKey = getStripeSecretKey();
            System.debug('API Key Format Valid: ' + isValidStripeKey(secretKey));
            System.debug('API Key Type: ' + (secretKey.startsWith('sk_test_') ? 'Test Mode' : 'Live Mode'));
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL + 'customers?limit=1');
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + secretKey);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Connection Test Status: ' + res.getStatusCode());
            System.debug('Connection Test Response: ' + res.getBody());
            
            if(res.getStatusCode() == 200) {
                return JSON.serialize(new Map<String,Object>{
                    'success' => true,
                    'message' => 'Stripe API connection successful',
                    'mode' => (secretKey.startsWith('sk_test_') ? 'test' : 'live')
                });
            } else {
                return JSON.serialize(new Map<String,Object>{
                    'success' => false,
                    'message' => 'API connection failed: ' + res.getStatus(),
                    'statusCode' => res.getStatusCode(),
                    'response' => res.getBody()
                });
            }
        } catch(Exception e) {
            System.debug('Connection test exception: ' + e.getMessage());
            return errorJson('Connection test failed: ' + e.getMessage());
        }
    }
    
    // Method to get account details by ID
    @RemoteAction
    public static String getAccountDetails(String accountId) {
        System.debug('=== Getting Account Details ===');
        System.debug('Account ID: ' + accountId);
        
        
        try {
            if (String.isBlank(accountId)) {
                return errorJson('Account ID is required');
            }
            
            // Query the account
            List<Account> accounts = [SELECT Id, Name, Type, Industry, BillingAddress, 
                                            Phone, Website, CreatedDate 
                                     FROM Account 
                                     WHERE Id = :accountId 
                                     LIMIT 1];
            
            if (accounts.isEmpty()) {
                return errorJson('Account not found with ID: ' + accountId);
            }
            
            Account acc = accounts[0];
            System.debug('Account found: ' + acc.Name + ' | Type: ' + acc.Type);
            
            Map<String, Object> accountData = new Map<String, Object>{
                'id' => acc.Id,
                'name' => acc.Name,
                'type' => acc.Type,
                'industry' => acc.Industry,
                'phone' => acc.Phone,
                'website' => acc.Website,
                'billingAddress' => acc.BillingAddress,
                'createdDate' => acc.CreatedDate
            };
            System.debug('Account details prepared: ' + JSON.serialize(accountData));
            return JSON.serialize(accountData);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in getAccountDetails:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to get account details: ' + e.getMessage());
        }
    }
    
    // Method to get invoice details including balance
    @RemoteAction
    public static String getInvoiceDetails(String invoiceId) {
        System.debug('=== Getting Invoice Details ===');
        System.debug('Invoice ID: ' + invoiceId);
        
        try {
            if (String.isBlank(invoiceId)) {
                return errorJson('Invoice ID is required');
            }
            
            // Query the custom Invoice__c object
            List<Invoice__c> invoices = [SELECT Id, Name, Status__c, BillingAccountId__c, BillingAccountId__r.Name, 
                                                TotalChargeAmountWithTax__c, TotalChargeTaxAmount__c, Balance__c,
                                                CreatedDate, DueDate__c, InvoiceDate__c 
                                                FROM Invoice__c 
                                                WHERE Id = :invoiceId 
                                                LIMIT 1];
            
            if (invoices.isEmpty()) {
                return errorJson('Invoice not found with ID: ' + invoiceId);
            }
            
            Invoice__c inv = invoices[0];
            System.debug('Invoice found: ' + inv.Name + ' | Total: ' + inv.TotalChargeAmountWithTax__c + ' | Balance: ' + inv.Balance__c);
            
            // Use the balance field from the custom object
            Decimal balance = inv.Balance__c != null ? inv.Balance__c : 0;
            Decimal totalAmount = inv.TotalChargeAmountWithTax__c != null ? inv.TotalChargeAmountWithTax__c : 0;
            
            Map<String, Object> invoiceData = new Map<String, Object>{
                'id' => inv.Id,
                'name' => inv.Name,
                'status' => inv.Status__c,
                'accountName' => inv.BillingAccountId__r?.Name,
                'totalAmount' => totalAmount,
                'balance' => balance,
                'createdDate' => inv.CreatedDate,
                'dueDate' => inv.DueDate__c,
                'invoiceDate' => inv.InvoiceDate__c
            };
            
            System.debug('Invoice details prepared: ' + JSON.serialize(invoiceData));
            return JSON.serialize(invoiceData);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in getInvoiceDetails:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to get invoice details: ' + e.getMessage());
        }
    }
    
    // Method to update invoice after successful payment and create payment records
    @RemoteAction
    public static String updateInvoiceAfterPayment(String invoiceId, String stripePaymentIntentId, Integer amountCents, String cardholderName) {
        System.debug('=== Updating Invoice After Payment ===');
        System.debug('Invoice ID: ' + invoiceId);
        System.debug('Stripe Payment Intent ID: ' + stripePaymentIntentId);
        System.debug('Amount in cents: ' + amountCents);
        System.debug('Cardholder Name: ' + cardholderName);
        
        try {
            if (String.isBlank(invoiceId)) {
                return errorJson('Invoice ID is required');
            }
            
            if (String.isBlank(stripePaymentIntentId)) {
                return errorJson('Stripe Payment Intent ID is required');
            }
            
            if (amountCents == null || amountCents <= 0) {
                return errorJson('Valid payment amount is required');
            }
            
            // Query the custom Invoice__c object with BillingAccountId__c
            List<Invoice__c> invoices = [SELECT Id, Name, Status__c, TotalChargeAmountWithTax__c, Balance__c,
                                                Payment_Status__c, Payment_Link__c, BillingAccountId__c
                                        FROM Invoice__c 
                                        WHERE Id = :invoiceId 
                                        LIMIT 1];
            
            if (invoices.isEmpty()) {
                return errorJson('Invoice not found with ID: ' + invoiceId);
            }
            
            Invoice__c inv = invoices[0];
            System.debug('Current Invoice Status: ' + inv.Status__c + ' | Total: ' + inv.TotalChargeAmountWithTax__c + ' | Balance: ' + inv.Balance__c);
            
            // Convert cents to dollars
            Decimal paidAmount = amountCents / 100.0;
            System.debug('Paid Amount: $' + paidAmount);
            
            // Create payment method and payment records
            String paymentMethodId = null;
            String paymentRecordId = null;
            
            try {
                // Create Payment Method record
                paymentMethodId = createPaymentMethod(
                    stripePaymentIntentId, // Use payment intent ID as Stripe payment method ID
                    String.isNotBlank(cardholderName) ? cardholderName : 'Online Payment User',
                    'Credit Card'
                );
                
                System.debug('✅ Payment Method created: ' + paymentMethodId);
                
                // Create Payment record
                paymentRecordId = createPaymentRecord(
                    invoiceId,
                    inv.BillingAccountId__c,
                    paymentMethodId,
                    paidAmount,
                    stripePaymentIntentId,
                    String.isNotBlank(cardholderName) ? cardholderName : 'Online Payment User'
                );
                
                System.debug('✅ Payment record created: ' + paymentRecordId);
                
            } catch (Exception paymentCreateError) {
                System.debug('❌ Error creating payment records: ' + paymentCreateError.getMessage());
                // Continue with invoice update even if payment record creation fails
                // But log the error for investigation
            }
            
            // Update invoice status
            inv.Payment_Status__c = 'Paid';
            inv.Status__c = 'Posted';
            inv.Balance__c = 0; 
            inv.Payment_Link__c = getVFPageURL(invoiceId);
            
            update inv;
            
            System.debug('Invoice updated successfully');
            System.debug('New Status: ' + inv.Status__c + ' | New Balance: ' + inv.Balance__c);
            
            Map<String, Object> result = new Map<String, Object>{
                'success' => true,
                'message' => 'Invoice updated successfully and payment records created',
                'invoiceId' => inv.Id,
                'accountId' => inv.BillingAccountId__c,
                'newStatus' => inv.Status__c,
                'newBalance' => inv.Balance__c,
                'paidAmount' => paidAmount,
                'stripePaymentIntentId' => stripePaymentIntentId,
                'paymentMethodId' => paymentMethodId,
                'paymentRecordId' => paymentRecordId
            };
            
            return JSON.serialize(result);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in updateInvoiceAfterPayment:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to update invoice: ' + e.getMessage());
        }
    }

    public static String getVFPageURL(String invoiceId){
        //?invoiceId=a0vgL000005KQpvQAG&accountId=001gL00000Ga4yNQAR
        PageReference pageRef = Page.paymentForm;
        
        // For Experience Sites, use Site.getBaseUrl() if available, otherwise fallback to org URL
        String baseURL;
        try {
            baseURL = Site.getBaseUrl();
            if (String.isBlank(baseURL)) {
                baseURL = System.Url.getOrgDomainUrl().toExternalForm();
            }
        } catch (Exception e) {
            baseURL = System.Url.getOrgDomainUrl().toExternalForm();
        }
        
        String accId = '';

        try{
            List<Invoice__c> parentAccountId = [SELECT BillingAccountId__c FROM Invoice__c WHERE Id =: invoiceId LIMIT 1];
            if(parentAccountId.size() > 0 && parentAccountId[0].BillingAccountId__c != null){
                accId = parentAccountId[0].BillingAccountId__c;
                System.debug('Parent Account Id: =================> ' + parentAccountId);
            }
        }catch(Exception e){
            System.debug('=====account Id in URL =======> '+ e.getMessage());
        }

        String fullURL = baseURL + pageRef.getUrl() + '?' + 'invoiceId=' + invoiceId + '&' + 'accountId=' + accId;

        return fullURL;
    }

    // Method to check if payment was completed and show thank you message
    @RemoteAction
    public static String checkPaymentCompletion(String invoiceId) {
        System.debug('=== Checking Payment Completion ===');
        System.debug('Invoice ID: ' + invoiceId);
        
        try {
            if (String.isBlank(invoiceId)) {
                return errorJson('Invoice ID is required');
            }
            
            // Query the invoice to check if it's paid
            List<Invoice__c> invoices = [SELECT Id, Name, Status__c, Payment_Status__c, 
                                                Balance__c, TotalChargeAmountWithTax__c
                                         FROM Invoice__c 
                                         WHERE Id = :invoiceId 
                                         LIMIT 1];
            
            if (invoices.isEmpty()) {
                return errorJson('Invoice not found with ID: ' + invoiceId);
            }
            
            Invoice__c inv = invoices[0];
            System.debug('Invoice Status: ' + inv.Status__c + ' | Payment Status: ' + inv.Payment_Status__c + ' | Balance: ' + inv.Balance__c);
            
            // Check if payment is completed
            Boolean isPaymentCompleted = (inv.Payment_Status__c == 'Paid' && inv.Balance__c == 0);
            
            Map<String, Object> result = new Map<String, Object>{
                'success' => true,
                'invoiceId' => inv.Id,
                'invoiceName' => inv.Name,
                'isPaymentCompleted' => isPaymentCompleted,
                'status' => inv.Status__c,
                'paymentStatus' => inv.Payment_Status__c,
                'balance' => inv.Balance__c,
                'totalAmount' => inv.TotalChargeAmountWithTax__c
            };
            
            return JSON.serialize(result);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in checkPaymentCompletion:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to check payment completion: ' + e.getMessage());
        }
    }
    
    // Method to get the first invoice created today
    @RemoteAction
    @AuraEnabled
    public static String getTodaysFirstInvoice() {
        System.debug('=== Getting Today\'s First Invoice ===');
        
        try {
            // Get today's date
            Date today = Date.today();
            System.debug('Looking for invoices created on: ' + today);
            
            // Query for invoices created today, ordered by creation time
            List<Invoice__c> todaysInvoices = [SELECT Id, Name, Status__c, BillingAccountId__c, 
                                                       BillingAccountId__r.Name, Balance__c, 
                                                       TotalChargeAmountWithTax__c, CreatedDate
                                                FROM Invoice__c 
                                                WHERE DAY_ONLY(CreatedDate) = :today
                                                AND Balance__c > 0
                                                ORDER BY CreatedDate ASC 
                                                LIMIT 1];
            
            if (todaysInvoices.isEmpty()) {
                System.debug('No invoices found for today with outstanding balance');
                return errorJson('No unpaid invoices found for today');
            }
            
            Invoice__c firstInvoice = todaysInvoices[0];
            System.debug('First invoice found: ' + firstInvoice.Name + ' | Balance: $' + firstInvoice.Balance__c);
            
            // Generate the payment URL for this invoice
            String paymentUrl = getVFPageURL(firstInvoice.Id);
            System.debug('Payment URL generated: ' + paymentUrl);
            
            Map<String, Object> result = new Map<String, Object>{
                'success' => true,
                'invoice' => new Map<String, Object>{
                    'id' => firstInvoice.Id,
                    'name' => firstInvoice.Name,
                    'status' => firstInvoice.Status__c,
                    'balance' => firstInvoice.Balance__c,
                    'totalAmount' => firstInvoice.TotalChargeAmountWithTax__c,
                    'accountId' => firstInvoice.BillingAccountId__c,
                    'accountName' => firstInvoice.BillingAccountId__r?.Name,
                    'createdDate' => firstInvoice.CreatedDate
                },
                'paymentUrl' => paymentUrl,
                'message' => 'Found today\'s first invoice: ' + firstInvoice.Name
            };
            
            return JSON.serialize(result);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in getTodaysFirstInvoice:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to get today\'s first invoice: ' + e.getMessage());
        }
    }
    
    @RemoteAction
    public static String validateInvoiceAccountRelationship(String invoiceId,String accountId){
        System.debug('========VALIDATE INVOICE AND ACCOUNT RELATIONSHIP===========');
        System.debug('Account id ===> ' + accountId);
        System.debug('Invoice id ===> ' + invoiceId);

        try {
            if(String.isBlank(invoiceId))return errorJson('Invoice Id is Required....');
            if(String.isBlank(accountId))return errorJson('Account Id is Required....');

            List<Invoice__c> invoices = [SELECT Id,Name,BillingAccountId__c, BillingAccountId__r.Name FROM Invoice__c  WHERE Id =: invoiceId AND BillingAccountId__c =: accountId LIMIT 1];
            if(invoices.isEmpty()){
                System.debug('===Invoice exists but belongs to different Person Account :======== ');

                List<Invoice__c> invoiceExists=[SELECT Id,BillingAccountId__c,BillingAccountId__r.Name FROM Invoice__c WHERE Id =: invoiceId Limit 1];
                if(invoiceExists.isEmpty())return errorJson('Invoice Id Not Found with Id : '+ invoiceId);
                else{
                    String actualName = invoiceExists[0].BillingAccountId__r?.Name;
                    return errorJson('Invoice does not belong to the specified account. This invoice belongs to: '+ actualName);
                }
            }

            Invoice__c inv = invoices[0];
            System.debug('====Invoice found and belongs to correct account=====');
            System.debug(invoices);
            System.debug('Validation successful: Invoice ' + inv.Name + ' belongs to account ' + inv.BillingAccountId__r.Name);

            Map<String,Object> result = new Map<String,object>{
                'success' => true,
                'message' => 'Invoice belongs to the specified account',
                'invoiceId' => inv.Id,
                'invoiceName' => inv.Name,
                'accountId' => inv.BillingAccountId__c,
                'accountName' => inv.BillingAccountId__r.Name
            };
            System.debug('============= result object =====================');
            System.debug(result);
            return JSON.serialize(result);
        } catch (Exception e) {
            System.debug('EXCEPTION in validateInvoiceAccountRelationship:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to validate invoice-account relationship: ' + e.getMessage());
        }
    }


    private static String createPaymentMethod(String stripePaymentMethodId, String cardHolderName , String paymentType){
        System.debug('====== CREATING PAYMENT METHOD ============');
        System.debug('Stripe payment method Id : =====> ' + stripePaymentMethodId);
        System.debug('Cardholder Name ========> ' + cardHolderName);
        System.debug('Payment Type ===========> ' + paymentType);

        try {

            String accountId = null;
            List<Account> acc = [SELECT Id,Name FROM Account WHERE RecordType.DeveloperName = 'PersonAccount' ORDER BY CreatedDate DESC LIMIT 1];
            
            if(acc.size() > 0)accountId = acc[0].Id;
            
            Payment_Method__c pm = new Payment_Method__c(
                Strip_Payment_ID__c = stripePaymentMethodId,
                Payment_Type__c = paymentType,
                Default_Payment_Method__c = true,
                Status__c = 'Valid',
                Account__c = accountId
            );
            insert pm;

            System.debug('====== PAYMENT METHOD CREATED SUCCESSFULLY ====================> ' + pm.Id);

            return pm.Id;

        } catch (Exception e) {
            System.debug(' Error creating Payment Method:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            throw e;
        }   
    }



    private static String createPaymentRecord(String invoiceId,String accountId,String paymentMethodId,Decimal amount,String stripePaymentIntentId,String paidByName){
        System.debug('========= CREATING PAYMENT RECORD ================');
        System.debug('Invoice Id =====> ' + invoiceId);
        System.debug('Account Id =======> ' + accountId);
        System.debug('Payment method Id =======>' + paymentMethodId);
        System.debug('Amount ===>' + amount);
        System.debug('Stripe Payment Intent Id =============> ' + stripePaymentIntentId);
        System.debug('Paid by mee =============> ' + paidByName);


        try{

            Payment__c payment = new Payment__c(
                Name = 'Payment - ' + stripePaymentIntentId,
                Invoice__c = invoiceId,
                Account__c = accountId,
                Payment_Method__c = paymentMethodId,
                Status__c = 'Posted',
                Balance__c = amount
            );

            insert payment;
            System.debug('=========== Payment Created ==================== '+ payment.Id);
            return payment.Id;


        }catch(Exception e){
            System.debug(' Error creating Payment record:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            throw e;
        }

    }
    
    // Method to get account associated with a user ID
    @AuraEnabled(cacheable=true)
    public static String getAccountByUserId(String userId) {
        System.debug('=== Getting Account for User ID ===');
        System.debug('User ID: ' + userId);
        
        try {
            if (String.isBlank(userId)) {
                return errorJson('User ID is required');
            }
            
            // Query user and their account relationships
            List<User> users = [SELECT Id, Name, Email, ContactId, Contact.AccountId,
                                    AccountId, Account.Id, Account.Name
                                FROM User 
                                WHERE Id = :userId 
                                LIMIT 1];
            
            if (users.isEmpty()) {
                return errorJson('User not found with ID: ' + userId);
            }
            
            User user = users[0];
            String accountId = null;
            String accountName = null;
            
            // Try multiple ways to get the account
            if (user.AccountId != null) {
                // Direct account relationship
                accountId = user.AccountId;
                accountName = user.Account?.Name;
                System.debug('Found account via direct AccountId: ' + accountId);
            } else if (user.ContactId != null && user.Contact.AccountId != null) {
                // Account through contact relationship
                accountId = user.Contact.AccountId;
                System.debug('Found account via Contact.AccountId: ' + accountId);
                
                // Get account name separately if needed
                if (accountName == null) {
                    List<Account> accounts = [SELECT Id, Name FROM Account WHERE Id = :accountId LIMIT 1];
                    if (!accounts.isEmpty()) {
                        accountName = accounts[0].Name;
                    }
                }
            }
            
            if (String.isBlank(accountId)) {
                return errorJson('No account found associated with user: ' + user.Name);
            }
            
            Map<String, Object> result = new Map<String, Object>{
                'success' => true,
                'accountId' => accountId,
                'accountName' => accountName,
                'userId' => user.Id,
                'userName' => user.Name,
                'userEmail' => user.Email
            };

            
            System.debug('Account found for user: ' + JSON.serialize(result));
            return JSON.serialize(result);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in getAccountByUserId:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to get account for user: ' + e.getMessage());
        }
    }
    
    // Method to get current user's invoice (for debugging)
    @RemoteAction
    @AuraEnabled
    public static String getCurrentUserInvoice() {
        System.debug('=== Getting Current User Invoice ===');
        
        try {
            String userId = UserInfo.getUserId();
            System.debug('Current User ID: ' + userId);
            
            // Get current user's account
            List<User> users = [SELECT Id, ContactId, Contact.AccountId, AccountId 
                               FROM User 
                               WHERE Id = :userId 
                               LIMIT 1];
            
            String currentUserAccountId = null;
            if (!users.isEmpty()) {
                User currentUser = users[0];
                if (currentUser.AccountId != null) {
                    currentUserAccountId = currentUser.AccountId;
                    System.debug('Found AccountId directly: ' + currentUserAccountId);
                } else if (currentUser.ContactId != null && currentUser.Contact.AccountId != null) {
                    currentUserAccountId = currentUser.Contact.AccountId;
                    System.debug('Found AccountId via Contact: ' + currentUserAccountId);
                }
            }
            
            if (String.isBlank(currentUserAccountId)) {
                return errorJson('No account found for current user');
            }
            
            // Get account name
            Account userAccount = [SELECT Id, Name FROM Account WHERE Id = :currentUserAccountId LIMIT 1];
            System.debug('User Account: ' + userAccount.Name);
            
            // Get latest invoice for this account
            List<Invoice__c> userInvoices = [SELECT Id, Name, Status__c, BillingAccountId__c, 
                                            BillingAccountId__r.Name, Balance__c, 
                                            TotalChargeAmountWithTax__c, CreatedDate
                                      FROM Invoice__c 
                                      WHERE BillingAccountId__c = :currentUserAccountId
                                      AND Balance__c > 0
                                      ORDER BY CreatedDate DESC 
                                      LIMIT 1];
            
            if (userInvoices.isEmpty()) {
                return errorJson('No invoices found for your account: ' + userAccount.Name);
            }
            
            Invoice__c userInvoice = userInvoices[0];
            System.debug('Found user invoice: ' + userInvoice.Name + ' for account: ' + userInvoice.BillingAccountId__r.Name);
            
            Map<String, Object> result = new Map<String, Object>{
                'success' => true,
                'invoice' => new Map<String, Object>{
                    'id' => userInvoice.Id,
                    'name' => userInvoice.Name,
                    'status' => userInvoice.Status__c,
                    'balance' => userInvoice.Balance__c,
                    'totalAmount' => userInvoice.TotalChargeAmountWithTax__c,
                    'accountId' => userInvoice.BillingAccountId__c,
                    'accountName' => userInvoice.BillingAccountId__r?.Name,
                    'createdDate' => userInvoice.CreatedDate
                },
                'message' => 'Found invoice for your account: ' + userAccount.Name
            };
            
            return JSON.serialize(result);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in getCurrentUserInvoice:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to get current user invoice: ' + e.getMessage());
        }
    }
    
    // Method to get the most recently created account's latest invoice (from userDetail component)
    @RemoteAction
    @AuraEnabled(cacheable=false)
    public static String getLatestInvoiceFromRecentAccount() {
        System.debug('=== Getting Latest Invoice from Most Recent Account ===');
        
        try {
            // Find the most recently created Person Account (created by userDetail component)
            List<Account> recentAccounts = [SELECT Id, Name, CreatedDate 
                                          FROM Account 
                                          WHERE RecordType.DeveloperName = 'PersonAccount'
                                          ORDER BY CreatedDate DESC 
                                          LIMIT 5]; // Get top 5 recent accounts
            
            if (recentAccounts.isEmpty()) {
                System.debug('No Person Accounts found');
                return errorJson('No Person Accounts found in the system');
            }
            
            System.debug('Found ' + recentAccounts.size() + ' recent Person Accounts');
            
            // Try to find an unpaid invoice from the most recent accounts
            for (Account account : recentAccounts) {
                System.debug('Checking account: ' + account.Name + ' (ID: ' + account.Id + ', Created: ' + account.CreatedDate + ')');
                
                // Check if this account has unpaid invoices
                List<Invoice__c> invoices = [SELECT Id, Name, Status__c, BillingAccountId__c, 
                                                BillingAccountId__r.Name, TotalChargeAmountWithTax__c, 
                                                Balance__c, CreatedDate, DueDate__c, InvoiceDate__c,
                                                Payment_Status__c
                                            FROM Invoice__c 
                                            WHERE BillingAccountId__c = :account.Id
                                                AND (Payment_Status__c = 'Unpaid' OR Payment_Status__c = null)
                                                AND Balance__c > 0
                                            ORDER BY CreatedDate DESC 
                                            LIMIT 1];
                
                if (!invoices.isEmpty()) {
                    Invoice__c invoice = invoices[0];
                    System.debug('Found unpaid invoice for account ' + account.Name + ': ' + invoice.Name + ' | Balance: $' + invoice.Balance__c);
                    
                    Map<String, Object> invoiceData = new Map<String, Object>{
                        'Id' => invoice.Id,
                        'Name' => invoice.Name,
                        'Status__c' => invoice.Status__c,
                        'AccountId' => invoice.BillingAccountId__c,
                        'AccountName' => invoice.BillingAccountId__r?.Name,
                        'TotalAmount' => invoice.TotalChargeAmountWithTax__c,
                        'Balance' => invoice.Balance__c,
                        'CreatedDate' => invoice.CreatedDate,
                        'DueDate' => invoice.DueDate__c,
                        'InvoiceDate' => invoice.InvoiceDate__c,
                        'PaymentStatus' => invoice.Payment_Status__c
                    };
                    
                    Map<String, Object> result = new Map<String, Object>{
                        'success' => true,
                        'invoice' => invoiceData,
                        'message' => 'Latest invoice found from recent account: ' + account.Name
                    };
                    
                    System.debug('Latest invoice from recent account: ' + JSON.serialize(result));
                    return JSON.serialize(result);
                }
            }
            
            System.debug('No unpaid invoices found in recent accounts');
            return errorJson('No unpaid invoices found in recently created accounts');
            
        } catch (Exception e) {
            System.debug('EXCEPTION in getLatestInvoiceFromRecentAccount:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to get invoice from recent account: ' + e.getMessage());
        }
    }
    
    // Method to get latest unpaid invoice by account name (useful for finding newly created accounts)
    @RemoteAction
    @AuraEnabled(cacheable=false)
    public static String getLatestInvoiceForAccountByName(String accountName) {
        System.debug('=== Getting Latest Invoice for Account by Name ===');
        System.debug('Account Name: ' + accountName);
        
        try {
            if (String.isBlank(accountName)) {
                return errorJson('Account name is required');
            }
            
            // First find the most recent account with this name
            List<Account> accounts = [SELECT Id, Name FROM Account 
                                     WHERE Name = :accountName 
                                     ORDER BY CreatedDate DESC 
                                     LIMIT 1];
            
            if (accounts.isEmpty()) {
                System.debug('No account found with name: ' + accountName);
                return errorJson('No account found with name: ' + accountName);
            }
            
            Account account = accounts[0];
            System.debug('Found account: ' + account.Id + ' - ' + account.Name);
            
            // Now get the latest unpaid invoice for this account
            List<Invoice__c> invoices = [SELECT Id, Name, Status__c, BillingAccountId__c, 
                                            BillingAccountId__r.Name, TotalChargeAmountWithTax__c, 
                                            Balance__c, CreatedDate, DueDate__c, InvoiceDate__c,
                                            Payment_Status__c
                                        FROM Invoice__c 
                                        WHERE BillingAccountId__c = :account.Id
                                            AND (Payment_Status__c = 'Unpaid' OR Payment_Status__c = null)
                                            AND Balance__c > 0
                                        ORDER BY CreatedDate DESC 
                                        LIMIT 1];
            
            if (invoices.isEmpty()) {
                System.debug('No unpaid invoices found for account: ' + account.Name);
                return errorJson('No unpaid invoices found for account: ' + account.Name);
            }
            
            Invoice__c invoice = invoices[0];
            System.debug('Found latest invoice: ' + invoice.Name + ' | Balance: $' + invoice.Balance__c);
            
            Map<String, Object> invoiceData = new Map<String, Object>{
                'Id' => invoice.Id,
                'Name' => invoice.Name,
                'Status__c' => invoice.Status__c,
                'AccountId' => invoice.BillingAccountId__c,
                'AccountName' => invoice.BillingAccountId__r?.Name,
                'TotalAmount' => invoice.TotalChargeAmountWithTax__c,
                'Balance' => invoice.Balance__c,
                'CreatedDate' => invoice.CreatedDate,
                'DueDate' => invoice.DueDate__c,
                'InvoiceDate' => invoice.InvoiceDate__c,
                'PaymentStatus' => invoice.Payment_Status__c
            };
            
            Map<String, Object> result = new Map<String, Object>{
                'success' => true,
                'invoice' => invoiceData,
                'message' => 'Latest invoice found for account: ' + account.Name
            };
            
            System.debug('Invoice found by account name: ' + JSON.serialize(result));
            return JSON.serialize(result);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in getLatestInvoiceForAccountByName:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to get invoice for account name: ' + e.getMessage());
        }
    }
    
    // Method to get latest unpaid invoice for a specific account
    @AuraEnabled(cacheable=false)
    public static String getLatestInvoiceForAccount(String accountId) {
        System.debug('=== Getting Latest Invoice for Account ===');
        System.debug('Account ID: ' + accountId);
        
        try {
            if (String.isBlank(accountId)) {
                return errorJson('Account ID is required');
            }
            
            // Query for the latest unpaid invoice for this account
            List<Invoice__c> invoices = [SELECT Id, Name, Status__c, BillingAccountId__c, 
                                            BillingAccountId__r.Name, TotalChargeAmountWithTax__c, 
                                            Balance__c, CreatedDate, DueDate__c, InvoiceDate__c,
                                            Payment_Status__c
                                        FROM Invoice__c 
                                        WHERE BillingAccountId__c = :accountId
                                            AND (Payment_Status__c = 'Unpaid' OR Payment_Status__c = null)
                                            AND Balance__c > 0
                                        ORDER BY CreatedDate DESC 
                                        LIMIT 1];
            
            if (invoices.isEmpty()) {
                System.debug('No unpaid invoices found for account: ' + accountId);
                return errorJson('No unpaid invoices found for this account.');
            }
            
            Invoice__c invoice = invoices[0];
            System.debug('Found latest invoice: ' + invoice.Name + ' | Balance: $' + invoice.Balance__c);
            
            Map<String, Object> invoiceData = new Map<String, Object>{
                'Id' => invoice.Id,
                'Name' => invoice.Name,
                'Status__c' => invoice.Status__c,
                'AccountId' => invoice.BillingAccountId__c,
                'AccountName' => invoice.BillingAccountId__r?.Name,
                'TotalAmount' => invoice.TotalChargeAmountWithTax__c,
                'Balance' => invoice.Balance__c,
                'CreatedDate' => invoice.CreatedDate,
                'DueDate' => invoice.DueDate__c,
                'InvoiceDate' => invoice.InvoiceDate__c,
                'PaymentStatus' => invoice.Payment_Status__c
            };
            
            Map<String, Object> result = new Map<String, Object>{
                'success' => true,
                'invoice' => invoiceData,
                'message' => 'Latest invoice found successfully'
            };
            
            System.debug('Latest invoice result: ' + JSON.serialize(result));
            return JSON.serialize(result);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in getLatestInvoiceForAccount:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to get latest invoice for account: ' + e.getMessage());
        }
    }

}
