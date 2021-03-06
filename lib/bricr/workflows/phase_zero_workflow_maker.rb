module BRICR
  # base class for objects that will configure workflows based on building sync files
  class PhaseZeroWorkflowMaker < WorkflowMaker
  
    def initialize(doc)
      super
      
      # load the workflow
      @workflow = nil
      
      workflow_path = File.join(File.dirname(__FILE__), '/phase_zero.osw')
      raise "File '#{workflow_path}' does not exist" if !File.exists?(workflow_path)
      
      File.open(workflow_path, 'r') do |file|
        @workflow = JSON::parse(file.read)
      end      
      
      if BRICR::OPENSTUDIO_MEASURES
        @workflow["measure_paths"] = BRICR::OPENSTUDIO_MEASURES
      end
      
      if BRICR::OPENSTUDIO_FILES
        @workflow["file_paths"] = BRICR::OPENSTUDIO_FILES
      end
  
      # configure the workflow based on properties in the xml
      configureForDoc(@workflow)
    end
  
    def configureForDoc(osw)
      # get the floor area
      floor_area = nil
      @doc.elements.each("/auc:Audits/auc:Audit/auc:Sites/auc:Site/auc:Facilities/auc:Facility/auc:FloorAreas/auc:FloorArea") do |floor_area_element|
        floor_area_type = floor_area_element.elements["auc:FloorAreaType"].text
        if (floor_area_type == "Gross")
          floor_area = floor_area_element.elements["auc:FloorAreaValue"].text.to_f
        end
      end
      
      # set this value in the osw
      set_measure_argument(osw, "Geometry", "floor_area", floor_area)
      
    end
        
    def configureForScenario(osw, scenario)
      measure_ids = []
      scenario.elements.each("auc:ScenarioType/auc:PackageOfMeasures/auc:MeasureIDs/auc:MeasureID") do |measure_id|
        measure_ids << measure_id.attributes["IDref"]
      end
      
      measure_ids.each do |measure_id|
        @doc.elements.each("//auc:Measure[@ID='#{measure_id}']") do |measure|
          measure_category = measure.elements["auc:SystemCategoryAffected"].text
          if /Lighting/.match(measure_category)
            set_measure_argument(osw, "AedgK12InteriorLightingControls", "__SKIP__", false)
          end
        end
      end
    end
    
    def writeOSWs(dir)
      super

      # write an osw for each scenario
      @doc.elements.each("auc:Audits/auc:Audit/auc:Report/auc:Scenarios/auc:Scenario") do |scenario|
      
        # get information about the scenario
        scenario_name = scenario.elements["auc:ScenarioName"].text

        # deep clone
        osw = JSON::load(JSON.generate(@workflow))
        
        # configure the workflow based on measures in this scenario
        configureForScenario(osw, scenario)
        
        # dir for the osw
        osw_dir = File.join(dir, scenario_name)
        FileUtils.mkdir_p(osw_dir)
        
        # write the osw
        path = File.join(osw_dir, 'in.osw')
        File.open(path, 'w') do |file|
          file << JSON.generate(osw)
        end
      end

    end
    
  end
end