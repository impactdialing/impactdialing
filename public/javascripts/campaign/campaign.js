function doRecord() {
    if ($("#campaign_use_recordings").attr('checked') == true) {
        $('#campaign_answering_machine_detect').attr('checked', true);
    }
    $("#recordingsdiv").toggle($("#campaign_use_recordings").checked);
}