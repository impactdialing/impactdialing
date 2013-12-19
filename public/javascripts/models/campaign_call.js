ImpactDialing.Models.CampaignCall = Backbone.Model.extend({
  initialize: function(){
    var self = this;
    ImpactDialing.Events.bind('transfer.kicked', function(){
      self.unset('kicking');
    });
  },

  kickTransferParticipant: function(postData, callbacks){
    var data = {
          caller_session_id: this.get('session_id')
        },
        options = {
          url: "/caller/" + this.get('caller_id') + "/kick",
          type: 'POST',
          data: _.extend(data, postData),
          beforeSend: function(request){
            var token = $("meta[name='csrf-token']").attr("content");
            request.setRequestHeader("X-CSRF-Token", token);
          }
        };
    _.extend(options, callbacks);
    $.ajax(options);
  },
  kickTransfer: function(callbacks){
    var data = {
          participant_type: 'transfer'
        };

    this.set({kicking: 'transfer'}, {silent: true});
    this.kickTransferParticipant(data, callbacks);
  },
  kickCaller: function(callbacks){
    var data = {
          participant_type: 'caller'
        };

    this.set({kicking: 'caller'}, {silent: true});
    this.kickTransferParticipant(data, callbacks);
  },
  isKicking: function(participant_type){
    return this.get('kicking') === participant_type;
  }
});