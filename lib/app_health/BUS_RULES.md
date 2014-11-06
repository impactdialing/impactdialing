## Dialing

### Machine Detection

When off: Voter#status is 'Hangup or answering machine' and these voters should be called back until answered or failed.

When on and not dropping messages: Voter#status is 'Hangup or answering machine' and these voters should be called back until answered or failed

When on and dropping messages and do not call back after message drop: Voter#status is 'Message delivered' and these voters should never be called back

When on and dropping messages and calling back after message drop: Voter#status is 'Message delivered' on first contact, 'Hangup or answering machine' on further contacts and these voters should be called back until answered by human or failed.

See `spec/features/customer_caller/call_back_spec.rb`.

## Reporting

Download reports are to be considered the canonical source for customer data.

All other reports are to be considered 'live' representations.

Example 1: if a Transfer is deleted from a Script then the number/percent of TransferAttempts to the deleted Transfer will only be visible in the Download reports.

Example 2: if a Question is deleted from a Script then Answers for that Question should still show in Download reports but not Answer reports.

[^ From quick chat with Michael July 30 2014]

Example 2 Problem: we won't have access to the Question text so not possible to include these in Download or other reports sensibly without the Question record (i.e. what good is an answer if you don't know the question).

    If we assume that Questions are only deleted during the first day or two of a Campaign (e.g. the admin customer made a mistake creating the Script), then there's little problem to just ignoring any Answers
    to deleted Questions; i.e. Example 2 problem goes away.

    If we assume that multiple admins are managing a Script and an outgoing (fired) admin who has not had their access revoked is going to come along and sabotage the Script by deleting Questions then that Campaign is mostly screwed. Assuming the problem is caught in time (within 2-4 wks of Questions deleted), we can pull their data from a database back-up but it will be a long and hairy process to export Questions for that campaign, insert them to the live database and then go through and update the campaign's Answers to associate with the freshly recovered Questions; i.e. Example 2 problem kills productivity for a few days.

[^ Example 2 problem is acceptable risk per chats with Michael July 31-August 1 2014]