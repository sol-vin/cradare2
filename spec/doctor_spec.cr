require "./spec_helper"

describe Cradare2::Util::Doctor do
  it "runs diagnostics and renders report with badges" do
    doc = Cradare2::Util::Doctor.new.run
    doc.items.should_not be_empty

    report = doc.render
    report.should contain("Environment & Toolchain Diagnostics")
    report.should contain("Crystal Compiler")
  end
end
