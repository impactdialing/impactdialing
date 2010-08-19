# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  def cms(key)
    s = Seo.find_by_crmkey_and_active_and_version(key,1,session[:seo_version])
    s = Seo.find_by_crmkey_and_active_and_version(key,1,nil) if s.blank?
    
    if s.blank?
      ""
    else
      s.content
    end
  end
  
  def float_sidebar
    @floatSidebar="<script>
    $('content').style.float='right'; 
    $('sidebar').style.float='left'; 

      var obj = document.getElementById('sidebar');
      if (obj.style.styleFloat) {
          obj.style.styleFloat = 'left';
      } else {
          obj.style.cssFloat = 'left';
      }

      var obj = document.getElementById('content');
      if (obj.style.styleFloat) {
          obj.style.styleFloat = 'right';
      } else {
          obj.style.cssFloat = 'right';
      }
      
      </script>";
      ""
  end
    
end
