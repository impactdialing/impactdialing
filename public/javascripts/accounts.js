$(document).ready(function(){
  $('.action-delete').click(function(element){
    if(confirm($(element.target).attr('data-message'))){
      $('#' + $(element.target).attr('data-form')).submit();
    }
  });

  $('.user_role').change(function(){
    $(this).parent('form').submit(function() {
    });  
    $(this).parent('form').trigger("submit");
    $(this).parent('form').unbind("submit");

  });


});
