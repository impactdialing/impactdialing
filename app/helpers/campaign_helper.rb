module CampaignHelper
  def options_for_select_campaign_type(campaign)
    options = []
    if can? :manage, Preview
      options << Campaign::Type::PREVIEW
    end
    if can? :manage, Power
      options << Campaign::Type::POWER
    end
    if can? :manage, Predictive
      options << Campaign::Type::PREDICTIVE
    end
    options.map!{|o| [o,o]}
    options_for_select options, campaign.type
  end

  def am_pm_hour_select(field_name)
    select_tag(field_name,options_for_select([
        ["1 AM", "01"],["2 AM", "02"],["3 AM", "03"],["4 AM", "04"],["5 AM", "05"],["6 AM", "06"],
        ["7 AM", "07"],["8 AM", "08"],["9 AM", "09"],["10 AM", "10"],["11 AM", "11"],["Noon", "12"],
        ["1 PM", "13"],["2 PM", "14"],["3 PM", "15"],["4 PM", "16"],["5 PM", "17"],["6 PM", "18"],
        ["7 PM", "19"],["8 PM", "20"],["9 PM", "21"],["10 PM", "22"],["11 PM", "23"],["Midnight", "0"]]))
  end

  def hours
    [["1 AM", "1"],["2 AM", "2"],["3 AM", "3"],["4 AM", "4"],["5 AM", "5"],["6 AM", "6"],
    ["7 AM", "7"],["8 AM", "8"],["9 AM", "9"],["10 AM", "10"],["11 AM", "11"],["Noon", "12"],
    ["1 PM", "13"],["2 PM", "14"],["3 PM", "15"],["4 PM", "16"],["5 PM", "17"],["6 PM", "18"],
    ["7 PM", "19"],["8 PM", "20"],["9 PM", "21"],["10 PM", "22"],["11 PM", "23"],["Midnight", "0"],]
  end

  def numbers_count_for(list)
    list.households_count
  end


  def missing_data_text(collection, collection_dependency, &block)
    add_dependency_msg = "In order to add a new #{collection}, you must first "
    link = link_to("add a new #{collection_dependency}", "new_client_#{collection_dependency}_path")
    no_collection_msg = "No #{collection}s entered."
    if collection.empty?
      rendered_message = no_collection_msg
      if collection_dependency.empty?
        rendered_message = content_tag(:div, class: ["callout", "alert", "clearfix"]) do
          (content_tag(:p, add_dependency_msg + link))
        end
      end
      return rendered_message
    else
      yield
    end
  end
  #
  # <% if @campaigns.empty? %>
  #   <p>No campaigns entered.</p>
  #   <% if @account.scripts.active.empty? %>
  #     <div class="callout alert clearfix">
  #       <p>
  #         In order to add a new campaign, you must first
  #         <%= link_to 'add a new script', new_client_script_path %>.
  #       </p>
  #   </div>
  #   <% end %>
  # <% else %>

  # def playground(collection_one, collection_two)
  #   if collection_one.empty?
  #     # return collection_two.join
  #     if false
  #     else
  #       'other' +
  #       'not other'
  #     end
  #   else
  #     yield
  #   end
  # end
end

  #
  # #########
  #       content_tag(:p, "Hello world!")
  #  # => <p>Hello world!</p>
  # content_tag(:div, content_tag(:p, "Hello world!"), class: "strong")
  #  # => <div class="strong"><p>Hello world!</p></div>
  # content_tag(:div, "Hello world!", class: ["strong", "highlight"])
  #  # => <div class="strong highlight">Hello world!</div>
  # content_tag("select", options, multiple: true)
  #  # => <select multiple="multiple">...options...</select>
  #
  # <%= content_tag :div, class: "strong" do -%>
  #   Hello world!
  # <% end -%>
  #  => <div class="strong">Hello world!</div>
