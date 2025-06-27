public with sharing class InvoiceController {
    public String companyName { get; set; }
    public String companyAddress { get; set; }
    public String opportunityOwner { get; set; }
    public String invoiceNumber { get; set; }
    public String todayDate { get; set; }
    public String contactName { get; set; }
    public String accountName { get; set; }
    public String contactPhone { get; set; }
    public String contactEmail { get; set; }
    public List<LineItem> products { get; set; }
    public Decimal totalAmount { get; set; }
    public String currencySymbol { get; set; }

    public InvoiceController() {
        try {
            Organization org = [SELECT Name, Street, City, State, Country, PostalCode FROM Organization LIMIT 1];
            companyName = org.Name;
            companyAddress = formatAddress(org);

            String oppId = ApexPages.currentPage().getParameters().get('id');
            if (String.isBlank(oppId)) {
                System.debug(LoggingLevel.ERROR, 'InvoiceController: Missing Opportunity ID');
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Opportunity ID is missing'));
                return;
            }

            Opportunity opp = [
                SELECT Id, Name, Owner.Name, Invoice_Number__c, CloseDate,
                       Account.Name,
                       (SELECT Product2.Name, Quantity, UnitPrice, TotalPrice FROM OpportunityLineItems)
                FROM Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];

            invoiceNumber = opp.Invoice_Number__c;
            opportunityOwner = opp.Owner != null ? opp.Owner.Name : 'Unknown';
            todayDate = Date.today().format();
            accountName = opp.Account != null ? opp.Account.Name : 'Unknown';

            products = new List<LineItem>();
            totalAmount = 0;
            for (OpportunityLineItem item : opp.OpportunityLineItems) {
                products.add(new LineItem(item));
                totalAmount += item.TotalPrice != null ? item.TotalPrice : 0;
            }

            Contact primaryContact = getContactForOpportunity(opp.Id);
            contactName = primaryContact.Name != null ? primaryContact.Name : 'Not specified';
            contactPhone = primaryContact.Phone != null ? primaryContact.Phone : '';
            contactEmail = primaryContact.Email != null ? primaryContact.Email : '';

            currencySymbol = '$';

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'InvoiceController Error: ' + e.getMessage() + ' at line: ' + e.getLineNumber());
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Invoice generation error: ' + e.getMessage()
            ));
        }
    }

    public class LineItem {
        public String productName { get; set; }
        public Decimal quantity { get; set; }
        public Decimal unitPrice { get; set; }
        public Decimal totalPrice { get; set; }

        public LineItem(OpportunityLineItem item) {
            productName = item.Product2 != null ? item.Product2.Name : 'Unnamed Product';
            quantity = item.Quantity != null ? item.Quantity : 0;
            unitPrice = item.UnitPrice != null ? item.UnitPrice : 0;
            totalPrice = item.TotalPrice != null ? item.TotalPrice : 0;
        }
    }

    private Contact getContactForOpportunity(Id oppId) {
        try {
            OpportunityContactRole role = [
                SELECT Contact.Id, Contact.Name, Contact.Phone, Contact.Email
                FROM OpportunityContactRole
                WHERE OpportunityId = :oppId AND IsPrimary = TRUE AND Contact.Email != null
                LIMIT 1
            ];

            if (role != null && role.Contact != null) {
                return role.Contact;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'No primary contact with email found or error: ' + e.getMessage());
        }

        try {
            OpportunityContactRole roleAny = [
                SELECT Contact.Id, Contact.Name, Contact.Phone, Contact.Email
                FROM OpportunityContactRole
                WHERE OpportunityId = :oppId AND Contact.Email != null
                LIMIT 1
            ];

            if (roleAny != null && roleAny.Contact != null) {
                return roleAny.Contact;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'No contact with email found or error: ' + e.getMessage());
        }

        return new Contact(
            LastName = 'Not specified',
            Phone = '',
            Email = ''
        );
    }

    private String formatAddress(Organization org) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(org.Street)) parts.add(org.Street);
        if (String.isNotBlank(org.City)) parts.add(org.City);
        if (String.isNotBlank(org.State)) parts.add(org.State);
        if (String.isNotBlank(org.PostalCode)) parts.add(org.PostalCode);
        if (String.isNotBlank(org.Country)) parts.add(org.Country);
        return String.join(parts, ', ');
    }

    // --- Методы для LWC и отправки Email ---

    @AuraEnabled(cacheable=true)
    public static ContactInfo getPrimaryContact(Id opportunityId) {
        try {
            OpportunityContactRole[] roles = [
                SELECT Contact.Name, Contact.Email, Contact.Phone 
                FROM OpportunityContactRole 
                WHERE OpportunityId = :opportunityId 
                  AND IsPrimary = TRUE
                  AND Contact.Email != null
                LIMIT 1
            ];

            if (!roles.isEmpty()) {
                return new ContactInfo(
                    roles[0].Contact.Name,
                    roles[0].Contact.Email,
                    roles[0].Contact.Phone
                );
            }

            roles = [
                SELECT Contact.Name, Contact.Email, Contact.Phone 
                FROM OpportunityContactRole 
                WHERE OpportunityId = :opportunityId 
                  AND Contact.Email != null
                LIMIT 1
            ];

            if (!roles.isEmpty()) {
                return new ContactInfo(
                    roles[0].Contact.Name,
                    roles[0].Contact.Email,
                    roles[0].Contact.Phone
                );
            }

            return new ContactInfo('Not specified', '', '');

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class ContactInfo {
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;

        public ContactInfo(String name, String email, String phone) {
            this.name = name;
            this.email = email;
            this.phone = phone;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<EmailTemplate> getEmailTemplates() {
        return [
            SELECT Id, Name 
            FROM EmailTemplate 
            WHERE DeveloperName LIKE 'Invoice%' 
            ORDER BY LastModifiedDate DESC
            LIMIT 10
        ];
    }

    @AuraEnabled
    public static String getEmailTemplateBody(Id templateId, Id opportunityId) {
        try {
            Messaging.SingleEmailMessage mail = Messaging.renderStoredEmailTemplate(templateId, null, opportunityId);
            return mail.getHtmlBody();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ContentDocumentLinkWrapper> getContentDocumentLinks(Id recordId, String fileType) {
        List<ContentDocumentLinkWrapper> result = new List<ContentDocumentLinkWrapper>();
        try {
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileType
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :recordId
                AND ContentDocument.FileType = :fileType
                ORDER BY ContentDocument.CreatedDate DESC
            ];
            for (ContentDocumentLink link : links) {
                result.add(new ContentDocumentLinkWrapper(
                    link.ContentDocumentId,
                    link.ContentDocument.Title,
                    link.ContentDocument.FileType
                ));
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return result;
    }

    public class ContentDocumentLinkWrapper {
        @AuraEnabled public Id ContentDocumentId;
        @AuraEnabled public String Title;
        @AuraEnabled public String FileType;

        public ContentDocumentLinkWrapper(Id contentDocumentId, String title, String fileType) {
            this.ContentDocumentId = contentDocumentId;
            this.Title = title;
            this.FileType = fileType;
        }
    }

    @AuraEnabled
    public static void sendInvoiceEmail(Id opportunityId, Id templateId, String subject, String body, String toAddress) {
        try {
            ContentDocumentLink[] links = [
                SELECT ContentDocumentId 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :opportunityId 
                ORDER BY SystemModstamp DESC 
                LIMIT 1
            ];

            if (links.isEmpty()) {
                throw new AuraHandledException('No invoice found for this opportunity');
            }

            ContentVersion contentVersion = [
                SELECT VersionData 
                FROM ContentVersion 
                WHERE ContentDocumentId = :links[0].ContentDocumentId 
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(UserInfo.getUserId());
            mail.setTemplateId(templateId);
            mail.setWhatId(opportunityId);
            mail.setSaveAsActivity(false);
            mail.setToAddresses(new String[] {toAddress});
            mail.setSubject(subject);
            mail.setHtmlBody(body);

            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName('Invoice.pdf');
            attachment.setBody(contentVersion.VersionData);
            mail.setFileAttachments(new Messaging.EmailFileAttachment[] {attachment});

            Messaging.sendEmail(new Messaging.SingleEmailMessage[] {mail});
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}