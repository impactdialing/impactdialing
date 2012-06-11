var Scripts = function(){}

Scripts.prototype.display_question_numbers = function(){
  var question_count = 1;    
  $.each($('.question_label'), function(){
	if ($(this).parent('fieldset').attr('deleted') != "true") {
      $(this).text("Question "+question_count++);
    }
  });

}

Scripts.prototype.mark_questions_answered = function(answered_questions){
	// questions_json = jQuery.parseJSON( answered_questions )
	// $.each($('.delete_question'), function(){
	//   var question_id = $($(this).parent('.nested-fields').children('.identity')[0]).val();
	//   $(this).attr('answered',questions_json[question_id])
	//     });    
}

Scripts.prototype.display_text_field_numbers = function(){
  var text_field_count = 1;
  $.each($('.text_field_label'), function(){
    if ($(this).parent('fieldset').attr('deleted') != "true") {
      $(this).text("Text Field "+text_field_count++);
	}
  });
}

Scripts.prototype.add_new_response_when_question_added = function(){
  $.each($('.question'), function(){
    if ($(this).children('.possible_response').length == 0) {
      $(this).children('.add_response').trigger('click')
    }      
  });    
}

function question_delete(question_node){
if($('#script_questions').children('.nested-fields').length == 1){
      alert("You must have at least one question");
      return false;
    }
    else{
 	  return true;
    }    	
  
  var question_id = $($(question_node).parent('.nested-fields').children('.identity')[0]).val();
  return question_answered(question_id);
}

function question_answered(question_id){
  $.ajax({
    url : "/client/scripts/question_answered",
    data : {question_id : question_id },
    type : "GET",
	async : false,
    success : function(response) {
	 if (response["data"] == true) {
		alert("You cannot delete this question as it has already been answered.");
		return false;		
	 }
	return true;
    }
  });
}

function possible_response_delete(response_node){
  var question = $(response_node).parents('.question');
  if($(question).children('.possible_response').length == 1) {
    alert("You must have at least one response.");
    return false;
  }
  else{
	  return true;
  }    	
}
