var Subscriptions = function(){
	if($("#subscription_type").val() == "PerMinute"){
  	this.showPerMinuteOptions();
   }else{
   	this.showPerAgentOptions();
   }
   this.submitPaymentEvent();
   this.subscriptionTypeChangeEvent();
   this.number_of_callers_reduced();   
   this.upgrade_to_per_minute();
   this.calculatedTotalMonthlyCost();

}

Subscriptions.prototype.showPerMinuteOptions = function(){
	$("#add_to_balance").show();
  $("#num_of_callers_section").hide();
}

Subscriptions.prototype.showPerAgentOptions = function(){
	$("#add_to_balance").hide();
	$("#num_of_callers_section").show(); 
}

Subscriptions.prototype.stripeResponseHandler = function(status, response){
	var $form = $('#payment-form');
    if (response.error) {
      $('#payment-flash').show();
      $('.payment-errors').text(response.error.message);
      $form.find('button').prop('disabled', false);
      } else {
      $('#payment-flash').hide();
      $('.payment-errors').text("");
      var token = response.id;        
      $form.append($('<input type="hidden" name="subscription[stripeToken]" />').val(token));        
      $form.get(0).submit();
     }
}

Subscriptions.prototype.submitPaymentEvent = function(){
	var self = this;
	$('#submit-payment').click(function(event) {
  	var $form = $("#payment-form");
    $form.find('button').prop('disabled', true);        
    Stripe.createToken($form, self.stripeResponseHandler);       
    return false;
   });
}

Subscriptions.prototype.subscriptionTypeChangeEvent = function(){
	var self = this;
	$("#subscription_type").change(function() {
  	if($(this).val() == "PerMinute"){
    	self.showPerMinuteOptions();        
    }else{
    	self.showPerAgentOptions();
      self.calculatedTotalMonthlyCost();
    }
	});
}

Subscriptions.prototype.calculatedTotalMonthlyCost = function(){
  $("#monthly-cost").hide();
  return if $("#subscription_type").val() == "PerMinute"
  var subscriptions = {"Basic": 49.00, "Pro": 99.00, "Business": 199.00}  
  var value = (subscriptions[$("#subscription_type").val()] * $("#number_of_callers").val())
  $("#monthly-cost").html(value);
  $("#monthly-cost").show();
}

Subscriptions.prototype.number_of_callers_reduced = function(){
  var self = this;
	$("#number_of_callers").on("change", function(){
    self.calculatedTotalMonthlyCost();
		if($(this).val()< 1){
			alert("You need to have atleast 1 caller.")			
			return;
		}
		if($(this).val() < $(this).data("value")){
			alert("On reducing the number of callers your minutes you paid for will still be retained, however you wont be refunded for the payment already made for the caller.")
		}
		
	});
}

Subscriptions.prototype.upgrade_to_per_minute = function(){
  $("#subscription_type").change(function() {        
    if($(this).val() == "PerMinute" && $(this).data("value") != "Trial"){
      alert("You can upgrade to Per Minute once you consume all your current subscription Minutes.")
    }
  });
}



