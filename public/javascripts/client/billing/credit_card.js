var CreditCard = function(){
  var self;

  this.submitPaymentEvent();
  this.newDatePicker('#expiration_date');
};

CreditCard.prototype.newDatePicker = function(selector) {
  if( $(selector).length < 1 ) { return; }

  var self = this;
  $(selector).datepicker({
    changeMonth: true,
    changeYear: true,
    showButtonPanel: false,
    dateFormat: 'mm/yy',
    onClose: function(dateText, inst) {
      var month = $("#ui-datepicker-div .ui-datepicker-month :selected").val();
      var year = $("#ui-datepicker-div .ui-datepicker-year :selected").val();
      $(this).datepicker('setDate', new Date(year, month, 1));
      self.updateExpirationFields(year, month);
    }
  });
};

CreditCard.prototype.updateExpirationFields = function(year, month) {
  month = parseInt(month) + 1;
  console.log('exp fields', year, month);
  if( month < 10 ) {
    month = "0" + month.toString();
  }
  $('input[data-stripe="exp_month"]').val(month);
  $('input[data-stripe="exp_year"]').val(year);
};

CreditCard.prototype.stripeResponseHandler = function(status, response){
  var token, $form;
  $form = $('#payment-form');
  if (response.error) {
    console.log(response.error);
    $('#payment-flash').show();
    $('.payment-errors').text(response.error.message);
    $form.find('button').prop('disabled', false);
    $('#submitting-gif').remove();
  } else {
    token = response.id;
    $('#payment-flash').hide();
    $('.payment-errors').text("");
    $form.append($('<input type="hidden" name="stripeToken" />').val(token));
    console.log('stripeToken', token);
    $form.get(0).submit();
  }
};

CreditCard.prototype.submitPaymentEvent = function(){
  var self, $form, submitting_gif;
  self = this;
  $('#update-payment-info').click(function(event) {
    $form = $("#payment-form");
    $form.find('button').prop('disabled', true);
    submitting_gif = $('<img>')
                      .attr('src', '/stylesheets/images/submitting.gif')
                      .attr('id', 'submitting-gif')
                      .css({
                        verticalAlign: 'middle',
                        marginLeft: '2px'
                      });
    $(this).after(submitting_gif);
    Stripe.createToken($form, self.stripeResponseHandler);
    return false;
  });
};
