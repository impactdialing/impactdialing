class MailerRendering < AbstractController::Base  
  include AbstractController::Rendering
  include AbstractController::Layouts
  include AbstractController::Helpers
  include AbstractController::Translation
  include AbstractController::AssetPaths

  self.view_paths = "app/views"
  layout "email"

private
  def tt_longest(headers, values)
    longest = []
    headers.size.times{ longest << 0 }
    values.map! do |n|
      n.sort_by do |x|
        x.blank? ? 0 : x.size
      end.last
    end

    [headers,values].each do |items|
      items.each_with_index do |str,i|
        next if str.blank?
        l = longest[i]
        l = str.size > l ? str.size : l
        longest[i] = l
      end
    end
    # padding
    @longest = longest.map{|l| l += 5}
  end
end