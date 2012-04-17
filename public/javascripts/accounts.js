$(document).ready(function(){
  $('.action-delete').click(function(element){
    if(confirm($(element.target).attr('data-message'))){
      $('#' + $(element.target).attr('data-form')).submit();
    }
  });

});
