class TtReportingController < ApplicationController
  unloadable

  menu_item :time_tracker_menu_tab_reporting

  helper :queries
  include QueriesHelper
  helper :sort
  include SortHelper
  include TimeTrackersHelper

  def index
    fetch_query

    if @query.valid?
      @limit = per_page_option

      @booking_count = @query.booking_count
      @booking_pages = Paginator.new self, @booking_count, @limit, params['page']
      @offset ||= @booking_pages.current.offset
      @bookings = @query.bookings(:order => sort_clause,
                                  :offset => @offset,
                                  :limit => @limit)
      @booking_count_by_group = @query.booking_count_by_group

    end

    fetch_chart_data

    render :template => 'tt_reporting/index'
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def print_report
    fetch_query

    if @query.valid?
      @booking_count = @query.booking_count
      @bookings = @query.bookings(:order => sort_clause)
      @booking_count_by_group = @query.booking_count_by_group
    end

    @total_booked_time = help.time_dist2string((total_booked*3600).to_i)
    fetch_chart_data

    # prepare logo settings
    @logo_url = Setting.plugin_redmine_time_tracker[:report_logo_url]
    Setting.plugin_redmine_time_tracker[:report_logo_url].starts_with?("http://") ? @logo_external = true : @logo_external = false
    Setting.plugin_redmine_time_tracker[:report_logo_width].blank? ? @logo_width = "150" : @logo_width = Setting.plugin_redmine_time_tracker[:report_logo_width]

    render "print_report", :layout => false
  end
end

def total_booked
  hours = 0
  @bookings.each do |tb|
    hours += tb.hours_spent
  end
  hours
end

private

def fetch_query
  tt_retrieve_query
  # overwrite the initial column_names cause if no columns are specified, the Query class uses default values
  # which depend on issues
  @query.column_names = @query.column_names || [:project, :tt_booking_date, :get_formatted_start_time, :get_formatted_stop_time, :issue, :comments, :get_formatted_time]

  # temporarily limit the available filters and columns for the view!
  @query.available_filters.delete_if { |key, value| !key.to_s.start_with?('tt_') }
  @query.available_columns.delete_if { |item| !([:id, :user, :project, :tt_booking_date, :get_formatted_start_time, :get_formatted_stop_time, :issue, :comments, :get_formatted_time].include? item.name) }

  sort_init(@query.sort_criteria.empty? ? [['tt_booking_date', 'desc']] : @query.sort_criteria)
  sort_update(@query.sortable_columns)
end

def fetch_chart_data
  if @query.valid? && !(@bookings.empty? || @bookings.nil?)
    # if the user changes the date-order for the table values, we have to get the correct date, as starting-point for the chart
    @chart_start_date = [@bookings.last.started_on.to_date, @bookings.first.started_on.to_date].min
    @chart_data = Array.new

    # if the user changes the date-order for the table values, we have to sort the data correctly
    # so we create a dynamical method-call
    if @bookings.last.started_on <= @bookings.first.started_on
      m1 = :last
      m2 = :first
    else
      m1 = :first
      m2 = :last
    end

    (@bookings.send(m1).started_on.to_date..@bookings.send(m2).started_on.to_date).map do |date|
      hours = 0
      @bookings.each do |tb|
        hours += tb.hours_spent if tb.started_on.to_date == date
      end
      @chart_data.push(hours)
    end
  end
end