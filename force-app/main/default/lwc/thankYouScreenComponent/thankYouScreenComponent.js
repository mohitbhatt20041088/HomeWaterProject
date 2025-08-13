import { LightningElement, track, api } from 'lwc';
import getTodaysFirstInvoice from '@salesforce/apex/StripeIntentController.getTodaysFirstInvoice';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import USER_ID from '@salesforce/user/Id';
import getAccountByUserId from '@salesforce/apex/StripeIntentController.getAccountByUserId';
import getLatestInvoiceForAccount from '@salesforce/apex/StripeIntentController.getLatestInvoiceForAccount';
import getLatestInvoiceForAccountByName from '@salesforce/apex/StripeIntentController.getLatestInvoiceForAccountByName';
import getLatestInvoiceFromRecentAccount from '@salesforce/apex/StripeIntentController.getLatestInvoiceFromRecentAccount';

export default class ThankYouScreenComponent extends NavigationMixin(LightningElement) {
    @track isLoading = false;
    @track errorMessage = '';
    
    // Public properties that can be set by parent components
    @api recordId; // Current record ID if component is placed on a record page
    @api invoiceId; // Direct invoice ID passed from parent
    @api accountId; // Direct account ID passed from parent
    
    // Current page reference to get URL parameters
    @track currentPageReference;
    
    // User ID
    userId = USER_ID;
    
    async handlePayNow() {
        console.log('Pay Your First Invoice button clicked');
        
        this.isLoading = true;
        this.errorMessage = '';
        
        try {
            // Try to get current user's account and latest invoice first
            console.log('Getting current user\'s account and invoice...');
            
            let invoiceId = null;
            let accountId = null;
            let invoiceData = null;
            
            try {
                // First, get the current user's account
                console.log('Step 1: Getting account for current user...');
                const userAccountResult = await getAccountByUserId({ userId: this.userId });
                console.log('User account result:', userAccountResult);
                
                let userAccountData;
                if (typeof userAccountResult === 'string') {
                    userAccountData = JSON.parse(userAccountResult);
                } else {
                    userAccountData = userAccountResult;
                }
                
                if (userAccountData.success && userAccountData.accountId) {
                    accountId = userAccountData.accountId;
                    console.log('✅ Found user account:', accountId, '- Name:', userAccountData.accountName);
                    
                    // Now get the latest invoice for this account
                    console.log('Step 2: Getting latest invoice for account:', accountId);
                    const latestInvoiceResult = await getLatestInvoiceForAccount({ accountId: accountId });
                    console.log('Latest invoice result:', latestInvoiceResult);
                    
                    let latestInvoiceData;
                    if (typeof latestInvoiceResult === 'string') {
                        latestInvoiceData = JSON.parse(latestInvoiceResult);
                    } else {
                        latestInvoiceData = latestInvoiceResult;
                    }
                    
                    if (latestInvoiceData.success && latestInvoiceData.invoice) {
                        invoiceId = latestInvoiceData.invoice.Id;
                        invoiceData = {
                            success: true,
                            invoice: {
                                id: latestInvoiceData.invoice.Id,
                                name: latestInvoiceData.invoice.Name,
                                accountId: accountId,
                                accountName: userAccountData.accountName
                            }
                        };
                        console.log('✅ Using user-specific invoice and account');
                    }
                }
            } catch (userInvoiceError) {
                console.log('⚠️ Could not get user-specific invoice:', userInvoiceError.message);
            }
            
            // NEW: Try to find invoice from the most recently created account (from userDetail component)
            if (!invoiceId || !accountId) {
                console.log('Step 3: Trying to find invoice from recently created accounts...');
                
                try {
                    const recentAccountResult = await getLatestInvoiceFromRecentAccount();
                    console.log('Recent account result:', recentAccountResult);
                    
                    let recentAccountData;
                    if (typeof recentAccountResult === 'string') {
                        recentAccountData = JSON.parse(recentAccountResult);
                    } else {
                        recentAccountData = recentAccountResult;
                    }
                    
                    if (recentAccountData.success && recentAccountData.invoice) {
                        invoiceId = recentAccountData.invoice.Id;
                        accountId = recentAccountData.invoice.AccountId;
                        invoiceData = {
                            success: true,
                            invoice: {
                                id: recentAccountData.invoice.Id,
                                name: recentAccountData.invoice.Name,
                                accountId: accountId,
                                accountName: recentAccountData.invoice.AccountName
                            }
                        };
                        console.log(`✅ Found invoice for recently created account: ${recentAccountData.invoice.AccountName}`);
                    }
                } catch (recentAccountError) {
                    console.log(`⚠️ Could not find invoice from recent accounts:`, recentAccountError.message);
                }
            }
            
            // Fallback to today's first invoice if user-specific approach and name search failed
            if (!invoiceId || !accountId) {
                console.log('Fallback: Getting today\'s first invoice...');
                const result = await getTodaysFirstInvoice();
                
                console.log('Today\'s invoice result:', result);
                
                // Parse the result if it's a string
                if (typeof result === 'string') {
                    invoiceData = JSON.parse(result);
                } else {
                    invoiceData = result;
                }
                
                // Check for errors
                if (invoiceData.error) {
                    throw new Error(invoiceData.message || 'No unpaid invoices found');
                }
                
                if (invoiceData.success && invoiceData.invoice) {
                    invoiceId = invoiceData.invoice.Id || invoiceData.invoice.id;
                    accountId = invoiceData.invoice.accountId || invoiceData.invoice.AccountId || invoiceData.invoice.BillingAccountId__c;
                }
            }
            
            if (invoiceData && invoiceData.success && invoiceData.invoice && invoiceId && accountId) {
                console.log('Redirecting to payment portal with invoice:', invoiceData.invoice);
                
                // Show success message
                this.showToast(
                    'Invoice Found', 
                    `Redirecting to payment portal for ${invoiceData.invoice.name}`, 
                    'success'
                );
                
                // DEBUGGING: Log all invoice fields
                console.log('🔍 DEBUGGING - Complete invoice object:', invoiceData.invoice);
                console.log('🔍 DEBUGGING - Final IDs being used:', {
                    'invoiceId': invoiceId,
                    'accountId': accountId,
                    'accountName': invoiceData.invoice.accountName
                });
                
                console.log('✅ Using IDs - Invoice:', invoiceId, 'Account:', accountId);
                this.navigateToPaymentPortal(invoiceId, accountId);
            } else {
                throw new Error('Could not find valid invoice and account data');
            }
            
        } catch (error) {
            console.error('Error handling Pay Now:', error);
            
            // Show error message
            this.errorMessage = error.message || 'An error occurred while processing your request';
            
            this.showToast(
                'Error', 
                this.errorMessage, 
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }
    
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }
    
    // Navigate to the paymentPortal__c Experience Site page
    navigateToPaymentPortal(invoiceId, accountId) {
        console.log('🚀 Navigating to payment portal with IDs:', { invoiceId, accountId });
        
        // Validate IDs before navigation
        if (!invoiceId || !accountId) {
            console.error('❌ Missing required IDs for navigation');
            this.showToast('Navigation Error', 'Missing invoice ID or account ID', 'error');
            return;
        }
        
        // Use NavigationMixin for proper Salesforce navigation first, with URL fallback
        this.navigateToPaymentPortalWithFallback(invoiceId, accountId);
    }
    
    // Try NavigationMixin first, then fallback to direct URL
    navigateToPaymentPortalWithFallback(invoiceId, accountId) {
        // TEMPORARY FIX: Skip Lightning Navigation and go directly to URL fallback
        // This is because paymentPortal__c page might not be properly set up
        console.log('🔄 Skipping Lightning Navigation, using direct URL approach...');
        this.navigateToPaymentPortalByUrl(invoiceId, accountId);
        
        /* COMMENTED OUT UNTIL paymentPortal__c PAGE IS VERIFIED
        try {
            // Try Lightning Navigation first for Experience Builder
            console.log('🔄 Attempting Lightning Navigation to Experience Builder page...');
            
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: {
                    pageName: 'paymentPortal__c'
                },
                state: {
                    invoiceId: invoiceId,
                    accountId: accountId
                }
            }).then(() => {
                console.log('✅ Lightning Navigation successful');
            }).catch(navError => {
                console.log('⚠️ Lightning Navigation failed, using URL navigation:', navError.message);
                this.navigateToPaymentPortalByUrl(invoiceId, accountId);
            });
            
        } catch (error) {
            console.log('⚠️ NavigationMixin not available, using URL navigation:', error.message);
            this.navigateToPaymentPortalByUrl(invoiceId, accountId);
        }
        */
    }
    
    // Fallback navigation method using URL
    navigateToPaymentPortalByUrl(invoiceId, accountId) {
        // Get the current base URL
        const baseUrl = window.location.origin;
        const currentPath = window.location.pathname;
        
        console.log('🔍 Current URL analysis:');
        console.log('  - Origin:', baseUrl);
        console.log('  - Path:', currentPath);
        
        // Construct the URL for the Experience Builder payment page
        let paymentPortalUrl;
        
        // Always use Visualforce page in VF domain
        if (currentPath.includes('/s/')) {
            // Experience Builder detected - convert to Visualforce domain
            console.log('🏢 Experience Builder detected - using Visualforce page in VF domain');
            console.log('Current baseUrl:', baseUrl);
            
            // Convert Experience Site domain to Visualforce domain
            // From: https://orgfarm-ecd431a69e-dev-ed.develop.live-preview.salesforce-experi
            // To: https://orgfarm-ecd431a69e-dev-ed--c.develop.vf.force.com
            let vfDomain = baseUrl;
            
            // Extract the org identifier from the current domain
            const orgMatch = baseUrl.match(/https:\/\/(.*?)\./);
            if (orgMatch) {
                const orgId = orgMatch[1]; // e.g., "orgfarm-ecd431a69e-dev-ed"
                vfDomain = `https://${orgId}--c.develop.vf.force.com`;
            }
            
            console.log('Converted to VF domain:', vfDomain);
            
            // Use the Visualforce page with proper parameters
            paymentPortalUrl = `${vfDomain}/apex/paymentForm?invoiceId=${invoiceId}&accountId=${accountId}`;
            console.log('Constructed Visualforce URL:', paymentPortalUrl);
        } else {
            // Standard Salesforce environment - use Visualforce page
            console.log('🏬 Standard Salesforce detected - using Visualforce page');
            paymentPortalUrl = `${baseUrl}/apex/paymentForm?invoiceId=${invoiceId}&accountId=${accountId}`;
        }
        
        console.log('✅ Final payment URL:', paymentPortalUrl);
        console.log('📝 URL Parameters:');
        console.log('  - invoiceId:', invoiceId);
        console.log('  - accountId:', accountId);
        
        // Show user what's happening
        this.showToast('Opening Payment Form', 'Opening payment form in new tab...', 'info');
        
        // Create a temporary link and click it to avoid popup blockers
        console.log('🚀 Opening payment form in new tab...');
        const tempLink = document.createElement('a');
        tempLink.href = paymentPortalUrl;
        tempLink.target = '_blank';
        tempLink.rel = 'noopener noreferrer';
        tempLink.style.display = 'none';
        
        // Add to DOM, click, and remove
        document.body.appendChild(tempLink);
        tempLink.click();
        document.body.removeChild(tempLink);
        
        console.log('✅ Link clicked programmatically to open in new tab');
    }
    
    // Attempt navigation with fallback to VF page if Experience Builder page doesn't exist
    attemptNavigationWithFallback(experienceUrl, invoiceId, accountId) {
        // Create a temporary link to test the Experience Builder page
        const testLink = document.createElement('a');
        testLink.href = experienceUrl;
        testLink.style.display = 'none';
        document.body.appendChild(testLink);
        
        // Try to navigate to Experience Builder page
        const originalTitle = document.title;
        
        // Set a timeout to check if navigation worked
        setTimeout(() => {
            // If we're still on the same page after attempting navigation,
            // fall back to Visualforce page
            if (document.title === originalTitle && window.location.href === window.location.href) {
                console.log('⚠️ Experience Builder page not found, falling back to Visualforce page');
                const baseUrl = window.location.origin;
                const fallbackUrl = `${baseUrl}/apex/paymentForm?invoiceId=${invoiceId}&accountId=${accountId}`;
                console.log('🔗 Fallback URL:', fallbackUrl);
                window.location.href = fallbackUrl;
            }
        }, 1000);
        
        // Attempt the navigation
        console.log('🚀 Attempting navigation to:', experienceUrl);
        window.location.href = experienceUrl;
        
        // Cleanup
        document.body.removeChild(testLink);
    }
    
    
    // Dynamic method to get Invoice ID and Account ID from multiple sources
    async getDynamicIds() {
        console.log('🔍 Getting dynamic IDs from multiple sources...');
        
        let invoiceId = null;
        let accountId = null;
        
        // Priority 1: Use component properties if provided
        if (this.invoiceId && this.accountId) {
            console.log('✅ Using component properties');
            return {
                invoiceId: this.invoiceId,
                accountId: this.accountId
            };
        }
        
        // Priority 2: Get from URL parameters
        const urlParams = this.getUrlParameters();
        if (urlParams.invoiceId && urlParams.accountId) {
            console.log('✅ Using URL parameters');
            return {
                invoiceId: urlParams.invoiceId,
                accountId: urlParams.accountId
            };
        }
        
        // Priority 3: Get from today's first invoice (existing logic)
        try {
            const todaysInvoice = await this.getTodaysFirstInvoiceData();
            if (todaysInvoice.invoiceId && todaysInvoice.accountId) {
                console.log('✅ Using today\'s first invoice');
                return todaysInvoice;
            }
        } catch (error) {
            console.log('❌ Could not get today\'s invoice:', error.message);
        }
        
        // Priority 4: Get account from current user
        try {
            const userAccount = await this.getAccountFromCurrentUser();
            if (userAccount) {
                accountId = userAccount;
                console.log('✅ Got account from current user:', accountId);
                
                // Still need invoice ID - try to get latest unpaid invoice for this account
                const latestInvoice = await this.getLatestInvoiceForAccount(accountId);
                if (latestInvoice) {
                    invoiceId = latestInvoice;
                    console.log('✅ Got latest invoice for account:', invoiceId);
                }
            }
        } catch (error) {
            console.log('❌ Could not get account from user:', error.message);
        }
        
        // Priority 5: Use record ID if component is on a record page
        if (this.recordId) {
            console.log('✅ Using record ID from page context:', this.recordId);
            // Determine if recordId is an Invoice or Account
            if (this.recordId.startsWith('a03')) { // Invoice ID prefix
                invoiceId = this.recordId;
            } else if (this.recordId.startsWith('001')) { // Account ID prefix
                accountId = this.recordId;
            }
        }
        
        return { invoiceId, accountId };
    }
    
    // Get URL parameters
    getUrlParameters() {
        const urlParams = new URLSearchParams(window.location.search);
        return {
            invoiceId: urlParams.get('invoiceId'),
            accountId: urlParams.get('accountId'),
            recordId: urlParams.get('recordId')
        };
    }
    
    // Get today's first invoice data (separated from handlePayNow)
    async getTodaysFirstInvoiceData() {
        try {
            const result = await getTodaysFirstInvoice();
            
            let invoiceData;
            if (typeof result === 'string') {
                invoiceData = JSON.parse(result);
            } else {
                invoiceData = result;
            }
            
            if (invoiceData.error) {
                throw new Error(invoiceData.message || 'No unpaid invoices found for today');
            }
            
            if (invoiceData.success && invoiceData.invoice) {
                return {
                    invoiceId: invoiceData.invoice.Id || invoiceData.invoice.id,
                    accountId: invoiceData.invoice.AccountId || invoiceData.invoice.accountId,
                    invoice: invoiceData.invoice
                };
            }
            
            throw new Error('Invalid invoice data format');
        } catch (error) {
            throw new Error(`Failed to get today's invoice: ${error.message}`);
        }
    }
    
    // Get account associated with current user
    async getAccountFromCurrentUser() {
        try {
            console.log('Getting account for user ID:', this.userId);
            const result = await getAccountByUserId({ userId: this.userId });
            
            if (result) {
                let accountData;
                if (typeof result === 'string') {
                    accountData = JSON.parse(result);
                } else {
                    accountData = result;
                }
                
                if (accountData.error) {
                    throw new Error(accountData.message);
                }
                
                return accountData.accountId || accountData.Id;
            }
            
            throw new Error('No account found for current user');
        } catch (error) {
            throw new Error(`Failed to get user account: ${error.message}`);
        }
    }
    
    // Get latest unpaid invoice for an account
    async getLatestInvoiceForAccount(accountId) {
        try {
            console.log('Getting latest invoice for account:', accountId);
            const result = await getLatestInvoiceForAccount({ accountId: accountId });
            
            if (result) {
                let invoiceData;
                if (typeof result === 'string') {
                    invoiceData = JSON.parse(result);
                } else {
                    invoiceData = result;
                }
                
                if (invoiceData.error) {
                    console.log('No invoice found:', invoiceData.message);
                    return null;
                }
                
                if (invoiceData.success && invoiceData.invoice) {
                    console.log('Latest invoice found:', invoiceData.invoice.Name);
                    return invoiceData.invoice.Id;
                }
            }
            
            return null;
        } catch (error) {
            console.error('Error getting latest invoice:', error);
            return null;
        }
    }
    
}
