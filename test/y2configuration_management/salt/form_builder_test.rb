# Copyright (c) [2018] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "../../spec_helper"
require "y2configuration_management/salt/form_controller"
require "y2configuration_management/salt/form"
require "y2configuration_management/widgets"

describe Y2ConfigurationManagement::Salt::FormBuilder do
  subject(:builder) { described_class.new(controller, form) }
  let(:form) do
    Y2ConfigurationManagement::Salt::Form.from_file(FIXTURES_PATH.join("form.yml"))
  end
  let(:element) { form.find_element_by(locator: locator) }
  let(:controller) { instance_double(Y2ConfigurationManagement::Salt::FormController) }

  describe "#build" do
    context "when a locator of an input form element is given" do
      let(:locator) { locator_from_string("root#person#name") }

      it "returns a form containing a text widget" do
        form_widget = builder.build(locator)
        expect(form_widget.children).to be_all(Y2ConfigurationManagement::Widgets::Text)
        expect(form_widget.children).to contain_exactly(
          an_object_having_attributes(
            "locator" => locator_from_string("root#person#name")
          )
        )
      end

      it "returns a single value form" do
        form_widget = builder.build(locator)
        expect(form_widget).to be_scalar
      end
    end

    context "when a locator of a group form element is given" do
      let(:locator) { locator_from_string("root#person#address") }

      it "returns a form containing group widgets" do
        form_widget = builder.build(locator)
        expect(form_widget.children.map(&:relative_locator)).to contain_exactly(
          locator_from_string("#street"),
          locator_from_string("#country")
        )
      end
    end

    context "when a locator of a collection is given" do
      let(:locator) { locator_from_string("root#person#computers") }

      it "returns a form containing a collection widget" do
        form_widget = builder.build(locator)
        expect(form_widget.children).to contain_exactly(
          an_object_having_attributes(
            "relative_locator" => locator_from_string("brand")
          ),
          an_object_having_attributes(
            "relative_locator" => locator_from_string("disks")
          )
        )
      end
    end
  end
end
