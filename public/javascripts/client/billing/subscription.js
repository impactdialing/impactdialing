var Subscriptions = function(){
  var self;

  if($("#subscription_type").val() == "per_minute"){
    this.showper_minuteOptions();
  } else {
    this.showPerAgentOptions();
  }

  this.subscriptionTypeChangeEvent();
  this.number_of_callers_reduced();
  this.upgrade_to_per_minute();
  this.calculatedTotalMonthlyCost();

  window.setInterval(this.calculatedTotalMonthlyCost, 500);
};

Subscriptions.prototype.showper_minuteOptions = function(){
  $("#add_to_balance").show();
  $("#num_of_callers_section").hide();
};

Subscriptions.prototype.showPerAgentOptions = function(){
  $("#add_to_balance").hide();
  $("#num_of_callers_section").show();
};

Subscriptions.prototype.subscriptionTypeChangeEvent = function(){
  var self = this;
  $("#subscription_type").change(function() {
    if( $(this).val() == "per_minute" ){
      self.showper_minuteOptions();
    } else {
      self.showPerAgentOptions();
      self.calculatedTotalMonthlyCost();
    }
  });
};

Subscriptions.prototype.calculatedTotalMonthlyCost = function(){
  var value, plans;
  plans = {
    "basic": 49.00,
    "pro": 99.00,
    "business": 199.00
  }

  if( $("#subscription_type").val() != "per_minute" ){
    console.log('callers: ', $('#number_of_callers').val())
    console.log('plan: ', $('#subscription_type').val())
    value = (plans[$("#subscription_type").val()] * $("#number_of_callers").val());
    if( $('#number_of_callers').val()< 1 ){
      var msg = "You need to have at least 1 caller.";
      $('#callers-warning').text(msg);
      $('#callers-warning').show()
      return;
    } else {
      $('#callers-warning').hide();
    }
    if( $('#number_of_callers').val() < $('#number_of_callers').data('value') &&
        $('#subscription_type').val() == $('#subscription_type').data('value') ){
      var msg = "Removing callers is not prorated and takes effect immediately. " +
                "In other words, the minutes purchased along with caller seats "+
                "are left in your account while the number of available seats is reduced right away.";
      $('#callers-warning').text(msg);
      $('#callers-warning').show();
    } else {
      $('#callers-warning').hide();
    }
    $("#monthly-cost").text(value);
    $("#cost-subscription").show();
  }
};

Subscriptions.prototype.number_of_callers_reduced = function(){
  var self = this;
  $("#number_of_callers").on("change", function(){
    self.calculatedTotalMonthlyCost();
  });
};

Subscriptions.prototype.upgrade_to_per_minute = function(){
  var self = this;
  $("#subscription_type").change(function() {
    if( $(this).val() == "per_minute" ){
      $("#cost-subscription").hide();
    }
  });
};
