import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

import getPrimaryContact from '@salesforce/apex/InvoiceController.getPrimaryContact';
import getEmailTemplates from '@salesforce/apex/InvoiceController.getEmailTemplates';
import getEmailTemplateBody from '@salesforce/apex/InvoiceController.getEmailTemplateBody';
import sendInvoiceEmail from '@salesforce/apex/InvoiceController.sendInvoiceEmail';
import getContentDocumentLinks from '@salesforce/apex/InvoiceController.getContentDocumentLinks';

const OPPORTUNITY_FIELDS = [
    'Opportunity.Invoice_Number__c',
    'Opportunity.Amount',
    'Opportunity.Name',
    'Opportunity.Account.Name',
    'Opportunity.Owner.Name',
    'Opportunity.Owner.Email',
    'Opportunity.Owner.Phone'
];

export default class SendInvoiceModal extends LightningElement {
    @api recordId;

    emailSubject = '';
    emailBody = '';
    recipientName = '';
    recipientEmail = '';
    selectedTemplate = '';
    templateOptions = [];
    isSending = false;
    invoiceId = '';

    _dataLoaded = false;

    @wire(getRecord, { recordId: '$recordId', fields: OPPORTUNITY_FIELDS })
    opportunity;

    async renderedCallback() {
        if (this.recordId && !this._dataLoaded) {
            this._dataLoaded = true;
            await this.loadData();
        }
    }

    async loadData() {
        try {
            if (!this.recordId) {
                this.showError('Error', 'Record ID is not provided.');
                return;
            }

            const contact = await getPrimaryContact({ opportunityId: this.recordId });

            if (!contact || !contact.email) {
                this.showError('Error', 'Primary contact or email not found for this opportunity.');
                this.closeAction(); 
                return;
            }

            this.recipientName = contact.name;
            this.recipientEmail = contact.email;

            if (this.opportunity && this.opportunity.data) {
                const invoiceNumber = getFieldValue(this.opportunity.data, 'Opportunity.Invoice_Number__c') || '';
                this.emailSubject = `Invoice for Opportunity ${invoiceNumber}`;
            } else {
                this.emailSubject = 'Invoice for Opportunity';
            }

            const templates = await getEmailTemplates();
            this.templateOptions = templates.map(t => ({ label: t.Name, value: t.Id }));

            const invoiceLinks = await this.getLatestInvoice();
            if (invoiceLinks?.length > 0) {
                this.invoiceId = invoiceLinks[0].ContentDocumentId;
            } else {
                this.showError('Error', 'No invoice PDF found to attach. Please generate an invoice first.');
                this.closeAction();
            }

        } catch (error) {
            this.showError('Loading Error', this.parseError(error));
        }
    }

    async getLatestInvoice() {
        try {
            return await getContentDocumentLinks({
                recordId: this.recordId,
                fileType: 'PDF'
            });
        } catch (error) {
            this.showError('Invoice Loading Error', this.parseError(error));
            return [];
        }
    }

    handleTemplateChange(event) {
        this.selectedTemplate = event.detail.value;
        this.loadEmailTemplateBody();
    }

    async loadEmailTemplateBody() {
        if (!this.selectedTemplate) {
            this.emailBody = '';
            return;
        }
        try {
            this.emailBody = await getEmailTemplateBody({
                templateId: this.selectedTemplate,
                opportunityId: this.recordId
            });
        } catch (error) {
            this.showError('Template Loading Error', this.parseError(error));
        }
    }

    handleSubjectChange(event) {
        this.emailSubject = event.target.value;
    }

    handleRecipientNameChange(event) {
        this.recipientName = event.target.value;
    }

    handleRecipientEmailChange(event) {
        this.recipientEmail = event.target.value;
    }

    handleBodyChange(event) {
        this.emailBody = event.target.value;
    }

    handlePreview() {
        if (!this.invoiceId) {
            this.showError('Invoice Missing', 'No PDF invoice found to preview.');
            return;
        }
        window.open(`${window.location.origin}/sfc/servlet.shepherd/document/download/${this.invoiceId}`, '_blank');
    }

    async handleSend() {
        if (!this.recipientEmail) {
            this.showError('Recipient Email Required', 'Please enter a recipient email address.');
            return;
        }

        if (!this.selectedTemplate) {
            this.showError('Template Required', 'Please select an email template.');
            return;
        }

        if (!this.invoiceId) {
            this.showError('Invoice Missing', 'Cannot send email: No invoice PDF found to attach.');
            return;
        }

        this.isSending = true;
        try {
            await sendInvoiceEmail({
                opportunityId: this.recordId,
                templateId: this.selectedTemplate,
                subject: this.emailSubject,
                body: this.emailBody,
                toAddress: this.recipientEmail
            });

            this.showSuccess('Sent', 'Invoice email sent successfully!');
            this.closeAction();
        } catch (error) {
            this.showError('Sending Error', this.parseError(error));
        } finally {
            this.isSending = false;
        }
    }

    handleCancel() {
        this.closeAction();
    }

    showSuccess(title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'success' }));
    }

    showError(title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'error', mode: 'sticky' }));
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    parseError(error) {
        let message = 'An unexpected error occurred.';
        if (error) {
            if (error.body) {
                if (Array.isArray(error.body.output?.errors) && error.body.output.errors.length > 0) {
                    message = error.body.output.errors[0].message;
                } else if (error.body.message) {
                    message = error.body.message;
                } else if (typeof error.body === 'string') {
                    message = error.body;
                }
            } else if (error.message) {
                message = error.message;
            } else if (typeof error === 'string') {
                message = error;
            }
        }
        return message;
    }
}