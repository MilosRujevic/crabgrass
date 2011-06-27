class GoogleAnalyticsListener < Crabgrass::Hook::ViewListener
  include Singleton

  def footer_content(context)
    if enabled?
      %Q(
<script src="#{config["https"] ? "https://ssl." : "http://www."}google-analytics.com/urchin.js" type="text/javascript">
</script>
<script type="text/javascript">
_uacct = "#{config["site_id"]}";
urchinTracker();
</script>
      )
    end
  end

  protected
  def config
    current_site.evil.respond_to?(:[]) ? current_site.evil["google_analytics"] : nil
  end

  def enabled?
    config.nil? ? false : config["enabled"]
  end
end
