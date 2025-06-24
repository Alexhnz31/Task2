import { LightningElement, api } from 'lwc';
import generateInvoice from '@salesforce/apex/GenerateInvoiceService.generateInvoice';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class GenerateInvoiceQuickAction extends LightningElement {
    @api recordId;
    isLoading = false;
    error = null;
    showActions = true;
    timeoutId;

    disconnectedCallback() {
        if (this.timeoutId) {
            clearTimeout(this.timeoutId);
        }
    }

    handleGenerate() {
        this.isLoading = true;
        this.showActions = false;
        this.error = null;
        
        this.timeoutId = setTimeout(() => {
            this.handleTimeout();
        }, 10000);

        generateInvoice({ oppId: this.recordId })
            .then(() => {
                clearTimeout(this.timeoutId);
                this.showSuccess();
            })
            .catch(error => {
                clearTimeout(this.timeoutId);
                this.handleError(error);
            });
    }

    handleTimeout() {
        this.handleError(new Error('Operation timed out after 10 seconds. Please try again.'));
    }

    showSuccess() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Invoice generated successfully',
            variant: 'success'
        }));
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleError(error) {
        console.error('Error generating invoice:', error);
        this.error = this.parseError(error); 
        this.isLoading = false;
        this.showActions = true;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error generating invoice',
            message: this.error,
            variant: 'error',
            mode: 'sticky'
        }));
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    parseError(error) {
        let message = 'An unknown error occurred.';
        if (error) {
            if (error.body) {
                if (Array.isArray(error.body.output.errors) && error.body.output.errors.length > 0) {
                    message = error.body.output.errors[0].message;
                } else if (error.body.message) {
                    message = error.body.message;
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