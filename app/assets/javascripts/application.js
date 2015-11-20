//= require jquery
//= require jquery_ujs
//= require jquery-ui
//= require introjs
//= require cocoon
//= require helper
//= require plugins

$(function() {
  $(document).ajaxSend(function(e, xhr, options) {
    var token = $("meta[name='csrf-token']").attr("content");
    xhr.setRequestHeader("X-CSRF-Token", token);
  });
})

function delete_entity(form_id){
  if (confirm('Are you sure?'))
    $(form_id).submit();
}

function isNativeApp(){
  return (navigator.userAgent == "ImpactDialing-Android" || navigator.userAgent == "ImpactDialing-Apple");
}
