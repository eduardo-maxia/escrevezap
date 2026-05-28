class SeoController < ApplicationController
  # Public, never authenticated. Cache for an hour.
  skip_before_action :verify_authenticity_token, raise: false

  def robots
    expires_in 1.hour, public: true
    render plain: <<~ROBOTS
      # robots.txt — EscreveZap
      User-agent: *
      Allow: /
      Disallow: /app/
      Disallow: /admin/
      Disallow: /webhook/
      Disallow: /jobs/
      Disallow: /rails/

      Sitemap: #{SeoHelper::SITE_URL}/sitemap.xml
    ROBOTS
  end

  def sitemap
    expires_in 1.hour, public: true

    urls = []
    urls << { loc: SeoHelper::SITE_URL,                                        changefreq: "weekly",  priority: "1.0" }
    urls << { loc: "#{SeoHelper::SITE_URL}#{pricing_path}",                    changefreq: "monthly", priority: "0.8" }
    SeoPagesController.slugs.each do |slug|
      urls << { loc: "#{SeoHelper::SITE_URL}/#{slug}", changefreq: "weekly",  priority: "0.7" }
    end
    urls << { loc: "#{SeoHelper::SITE_URL}#{privacidade_path}",                changefreq: "yearly",  priority: "0.2" }
    urls << { loc: "#{SeoHelper::SITE_URL}#{termos_path}",                     changefreq: "yearly",  priority: "0.2" }

    xml = +'<?xml version="1.0" encoding="UTF-8"?>'
    xml << '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
    urls.each do |u|
      xml << "<url><loc>#{u[:loc]}</loc><changefreq>#{u[:changefreq]}</changefreq><priority>#{u[:priority]}</priority></url>"
    end
    xml << "</urlset>"

    render xml: xml
  end
end
