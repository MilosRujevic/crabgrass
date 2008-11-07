# um, so, yeah, basically we don't use ActiveRecord for this.
# lots of MySQL-specific stuff here.
class PageView < ActiveRecord::Base
  belongs_to :page
  
  def self.insert_delayed(page_or_id)
    page_id = (page_or_id.is_a?(Fixnum) ? page_or_id : page_or_id.id)
    connection.execute("INSERT DELAYED INTO #{table_name} (page_id) VALUES (#{connection.quote(page_id)})")
  end
  
  def self.update_page_terms
    begin
      connection.execute("LOCK TABLES #{table_name} WRITE, page_terms WRITE")
      connection.execute("CREATE TEMPORARY TABLE page_view_counts SELECT COUNT(*) AS c, page_id FROM #{table_name} GROUP BY page_id")
      connection.execute("UPDATE page_terms,page_view_counts SET page_terms.views = page_terms.views + page_view_counts.c WHERE page_terms.page_id = page_view_counts.page_id")
      connection.execute("DROP TEMPORARY TABLE page_view_counts")
      self.delete_all
    ensure
      connection.execute("UNLOCK TABLES")
    end
  end
end
