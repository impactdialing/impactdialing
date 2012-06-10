var Scripts = function(){}

Scripts.prototype.question_deleted = function(){
	if($('#script_questions').children('.nested-fields').length == 1){
      alert("You must have at least one question");
      return false;
    }
    else{
	  return true;
    }
}