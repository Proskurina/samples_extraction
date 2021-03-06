module Printables::Instance
  def print(printer_config)
    return if Rails.configuration.printing_disabled
    f = facts.with_predicate('a').first
    printer_name = printer_config[Printer.printer_type_for(f.object)]
    label_template = LabelTemplate.for_type(f.object).first
    PMB::PrintJob.new(
      printer_name:printer_name,
      label_template_id: label_template.first.external_id,
      labels:{body:[printable_object]}
    ).save
  end
end
