import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAttendanceStatus from '@salesforce/apex/AttendanceController.getAttendanceStatus';
import saveAttendance from '@salesforce/apex/AttendanceController.saveAttendance';

export default class AttendanceLogger extends LightningElement {
    @track users = [];
    @track error;
    @track isLoading = true;
    @track isUpdateMode = false;

    get submitButtonLabel() {
        return this.isUpdateMode ? 'Update' : 'Submit';
    }

    connectedCallback() {
        this.loadData();
    }

    loadData() {
        this.isLoading = true;
        this.error = null;

        getAttendanceStatus()
            .then(result => {
                // Map attendance records to users
                this.users = (result || []).map(record => ({
                    userId: record.Counsellor__c,
                    name: record.Counsellor__r.Name,
                    present: record.Present__c,
                    statusLabel: record.Present__c ? 'Assign' : 'Unassign',
                    statusClass: record.Present__c ? 'status-label Assign' : 'status-label Unassign',
                    attendanceId: record.Id
                }));
                this.isUpdateMode = this.users.length > 0;
                this.isLoading = false;
            })
            .catch(error => {
                this.handleError(error);
            });
    }

    handleToggleChange(event) {
        const userId = event.target.name;
        const isPresent = event.target.checked;

        this.users = this.users.map(user => {
            if (user.userId === userId) {
                return {
                    ...user,
                    present: isPresent,
                    statusLabel: isPresent ? 'Assign' : 'Unassign',
                    statusClass: isPresent ? 'status-label Assign' : 'status-label Unassign'
                };
            }
            return user;
        });
    }

    handleSubmit() {
        this.isLoading = true;
        this.error = null;

        // Only update users who have an existing attendance record
        const recordsToUpdate = this.users
            .filter(user => user.attendanceId)
            .map(user => ({
                sobjectType: 'Attendance__c',
                Id: user.attendanceId,
                Counsellor__c: user.userId,
                Present__c: user.present
            }));

        if (recordsToUpdate.length === 0) {
            this.isLoading = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'No Records',
                    message: 'No attendance records to update.',
                    variant: 'info'
                })
            );
            return;
        }

        saveAttendance({ attendanceRecords: recordsToUpdate })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: this.isUpdateMode ? 'Attendance Updated' : 'Attendance Recorded',
                        message: 'Counsellor attendance has been successfully ' +
                                (this.isUpdateMode ? 'updated' : 'recorded') + '.',
                        variant: 'success'
                    })
                );
                this.loadData();
            })
            .catch(error => {
                this.handleError(error);
            });
    }

    handleError(error) {
        this.error = (error.body && error.body.message)
            ? error.body.message
            : 'An unexpected error occurred. Please try again later.';
        this.isLoading = false;
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: this.error,
                variant: 'error'
            })
        );
    }
}