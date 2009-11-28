class <%= name %> < ActiveRecord::Base
<% for attribute in attributes.sort{|a,b| a.name<=>b.name} -%>
<% if attribute.name =~ /(_id)$/ -%>
  belongs_to :<%= attribute.name.gsub /_id$/, '' %>
<% end -%>
<% end -%>

<% if options[:has_position] -%>
  acts_as_list
<% end -%>

end

