import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

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
    outsideClickHandler; // <- ключевая переменная

    @wire(getRecord, { recordId: '$recordId', fields: OPPORTUNITY_FIELDS })
    opportunity;

    connectedCallback() {
        this.outsideClickHandler = this.handleOutsideClick.bind(this);
        document.addEventListener('click', this.outsideClickHandler);
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.outsideClickHandler);
    }

    async renderedCallback() {
        if (this.recordId && !this._dataLoaded) {
            this._dataLoaded = true;
            await this.loadData();
        }
    }

    async loadData() {
        try {
            if (!this.recordId) {
                this.showError('Ошибка', 'recordId не передан');
                return;
            }

            const contact = await getPrimaryContact({ opportunityId: this.recordId });

            if (!contact || !contact.email) {
                this.showError('Ошибка', 'Не найден основной контакт или email');
                return;
            }

            this.recipientName = contact.name;
            this.recipientEmail = contact.email;

            if (this.opportunity && this.opportunity.data) {
                const invoiceNumber = getFieldValue(this.opportunity.data, 'Opportunity.Invoice_Number__c') || '';
                this.emailSubject = `Invoice for Order ${invoiceNumber}`;
            } else {
                this.emailSubject = 'Invoice for Order';
            }

            const templates = await getEmailTemplates();
            this.templateOptions = templates.map(t => ({ label: t.Name, value: t.Id }));

            const invoiceLinks = await this.getLatestInvoice();
            if (invoiceLinks?.length > 0) {
                this.invoiceId = invoiceLinks[0].ContentDocumentId;
            }
        } catch (error) {
            this.showError('Ошибка загрузки', error.body?.message || error.message);
        }
    }

    async getLatestInvoice() {
        try {
            return await getContentDocumentLinks({
                recordId: this.recordId,
                fileType: 'PDF'
            });
        } catch (error) {
            this.showError('Ошибка загрузки инвойса', error.body?.message || error.message);
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
            this.showError('Ошибка загрузки шаблона', error.body?.message || error.message);
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
            this.showError('Нет инвойса', 'PDF инвойс не найден');
            return;
        }
        window.open(`${window.location.origin}/sfc/servlet.shepherd/document/download/${this.invoiceId}`, '_blank');
    }

    async handleSend() {
        if (!this.recipientEmail) {
            this.showError('Email получателя пустой', 'Укажите email');
            return;
        }

        if (!this.selectedTemplate) {
            this.showError('Шаблон не выбран', 'Выберите шаблон письма');
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

            this.showSuccess('Отправлено', 'Инвойс отправлен успешно');
            this.closeAction();
        } catch (error) {
            this.showError('Ошибка отправки', error.body?.message || error.message);
        } finally {
            this.isSending = false;
        }
    }

    handleCancel() {
        this.closeAction();
    }

    handleOutsideClick(event) {
        const modal = this.template.querySelector('.slds-p-around_medium');
        const panel = this.template.querySelector('lightning-quick-action-panel');
        const path = event.composedPath();

        const clickedInsideModal = modal && path.includes(modal);
        const clickedInsidePanel = panel && path.includes(panel);

        if (!clickedInsideModal && clickedInsidePanel) {
            this.closeAction();
        }
    }

    showSuccess(title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'success' }));
    }

    showError(title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'error' }));
    }

    closeAction() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}
