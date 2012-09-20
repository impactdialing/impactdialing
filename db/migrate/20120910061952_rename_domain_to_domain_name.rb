class RenameDomainToDomainName < ActiveRecord::Migration
  def up
    rename_column(:accounts, :domain, :domain_name)    
  end

  def down
    rename_column(:accounts, :domain_name, :domain)    
  end
end
