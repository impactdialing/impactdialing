function go_to_current_campaign(){
    var campaign_id = $('#campaign_current').val();
    document.location.href = "/callers/campaigns/"+campaign_id;
}