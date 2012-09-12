var Scripts = function(){

  var self = this;

  self.display_question_numbers();
  self.display_text_field_numbers();
  self.display_script_text_numbers();


  $("#script_elements").sortable({ cursor: 'crosshair' , axis: 'y' ,stop: function(event, ui) {
    self.display_question_numbers();
  self.display_script_text_numbers();
  self.display_text_field_numbers();
  }
  });


  $(".possible_response_sortable").sortable({ cursor: 'crosshair' , containment: 'parent', axis: 'y' });

  $('#script_submit').click(function() {
    self.set_possible_response_order();
    self.set_elements_order();
    return true;
  });

  $('#call_results').bind('insertion-callback',
    function() {
      self.display_script_text_numbers();
      self.display_question_numbers();
      self.display_text_field_numbers();
      self.add_new_response_when_question_added();
  });



  $('#call_results').bind('after-removal-callback',
    function() {
    self.display_script_text_numbers();
      self.display_question_numbers();
      self.display_text_field_numbers();
      self.add_new_response_when_question_added();

  });



}

Scripts.prototype.set_elements_order = function(){
  var count = 1;
  $.each($('.script_element'), function(){
      $(this).val(count++);
  });
}


Scripts.prototype.display_question_numbers = function(){
  var question_count = 1;
  $.each($('.question_label'), function(){
  if ($(this).parent('fieldset').attr('deleted') != "true") {
      $(this).text("Question "+question_count++);
    }
  });

}

Scripts.prototype.display_script_text_numbers = function(){
  var script_text_count = 1;
  $.each($('.script_label'), function(){
  if ($(this).parent('fieldset').attr('deleted') != "true") {
      $(this).text("Script Text "+script_text_count++);
    }
  });

}

Scripts.prototype.set_possible_response_order = function(){
  responses = $('.possible_response_sortable')
  $.each(responses, function(){
  var possible_response_order = 1;
  var possible_responses = $(this).find('.possible_response_order');
  $.each($(possible_responses), function(){
    $(this).val(possible_response_order++);
  });
  });

}



Scripts.prototype.mark_answered = function(){
  question_ids = new Array();
  $('#script_questions').find('.identity').each(function(){
     question_ids.push($(this).val());
  })
  questions_answered();
  possible_response_answered(question_ids);

}

Scripts.prototype.display_text_field_numbers = function(){
  var text_field_count = 1;
  $.each($('.text_field_label'), function(){
    if ($(this).parent('fieldset').attr('deleted') != "true") {
      $(this).text("Note "+text_field_count++);
  }
  });
}

Scripts.prototype.add_new_response_when_question_added = function(){
  $.each($('.question'), function(){
    if ($(this).find('.possible_response').length == 0) {
      $(this).children('.add_response').trigger('click')
    }
  });
}

Scripts.prototype.reorder_script_elements = function(){

}

function question_delete(question_node){
if(($('#script_questions').children('.nested-fields').length - $('fieldset.question[deleted="true"]').length) == 1){
      alert("You must have at least one question");
      return false;
    }
 else {
  if( $($(question_node).parent('.question').children('.identity')[0]).attr('answered') == "true"){
      var confirm_delete = confirm("This question has already been answered. Are you sure you want to delete it? You will lose all of its data.");
     return confirm_delete
  }
}
  return true;
}

function possible_response_answered(question_ids){
  $.ajax({
    url : "/client/scripts//possible_responses_answered",
    data : {question_ids : question_ids, id: $("#script_id").val() },
    type : "GET",
  async : false,
    success : function(response) {
    for (myKey in response["data"]){
      $('#call_results').find('.possible_response_identity').each(function(){
        if ($(this).val() == myKey) {
          $(this).attr('answered', true)
        }
      });
    }
  }
  });
}


function questions_answered(){
  var script_id = $('#script_id').val();
  $.ajax({
    url : "/client/scripts/questions_answered",
    data : {id : $("#script_id").val() },
    type : "GET",
  async : false,
    success : function(response) {
    for (myKey in response["data"]){
      $('#script_questions').find('.identity').each(function(){
        if ($(this).val() == myKey) {
          $(this).attr('answered', true)
        }
      });
    }
  }
  });
}

function possible_response_delete(response_node){

  question = $(response_node).parents('.question')[0];
  if(( $(question).find('table.possible_response').length  - $(question).find('table.possible_response[deleted="true"]').length ) == 1) {
    alert("You must have at least one response.");
    return false;
  }
  else{
    if( $($($(response_node).parents('.possible_response')[0]).children('.possible_response_identity')[0]).attr('answered') == "true"){
    var confirm_delete = confirm("This response has already been chosen. Are you sure you want to delete it? You will lose all of its data.");
    return confirm_delete
  }
  }
  return true;
}

