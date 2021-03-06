class PatientsController < ApplicationController
  before_filter :find_patient, :except => [:void]
  
  def show  
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil    
    session_date = (session[:datetime].to_date rescue Date.today)
     
    @current_range = Patient.active_range(@patient.id, session_date)  rescue nil
   
    if request.referrer.match(/people\/search\?|\/clinic|people\/create/i)
      @current_pregnancy_url =  "/patients/current_pregnancy/?patient_id=#{@patient.id}"
      redirect_to "/patients/confirm/?patient_id=#{@patient.id}&url=#{@current_pregnancy_url}" and return
    end
    
    @encounters = @patient.encounters.active.find(:all, :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ?", 
        @current_range[0]["START"], @current_range[0]["END"]]) rescue []
    
    @all_encounters = @patient.encounters.active.find(:all) rescue []
    
    @encounter_names = @patient.encounters.active.find(:all, :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ?", 
        @current_range[0]["START"], @current_range[0]["END"]]).map{|encounter| encounter.name}.uniq rescue []
			
    @names = @encounters.collect{|e|
      e.name.upcase
    }.uniq
    
    @all_names = @all_encounters.collect{|e|
      e.name.upcase
    }.uniq
    
    @current_encounter_names = @patient.encounters.active.find(:all, 
      :conditions => ["DATE_FORMAT(encounter_datetime, '%Y-%m-%d') = ?", (session[:datetime] ? session[:datetime].to_date : Date.today)]).collect{|e|
      e.name.upcase
    }
    
    @obstretrics_alert = (@all_names.include?("OBSTETRIC HISTORY") ? false : true)
    
    @medics_alert = (@all_names.include?("MEDICAL HISTORY") ? false : true)
    
    @social_alert = (@all_names.include?("SOCIAL HISTORY") ? false : true)
    
    @labs_alert = ((@all_names.include?("LAB RESULTS")) ? false : true)
    
    @sections = {
      "OBSTETRIC HISTORY" => {},
      "MEDICAL HISTORY" => {},
      "SOCIAL HISTORY" => {},
      "SURGICAL HISTORY" => {},      
      "LAB RESULTS" => {}
    }
    
    @all_encounters.each{|e|
      if !e.type.nil?
        case e.type.name
        when "OBSTETRIC HISTORY"
          e.observations.each{|o|
            @sections["OBSTETRIC HISTORY"][o.concept.name.name] = (o.answer_string rescue "") if !o.concept.nil?
          }
        when "MEDICAL HISTORY"
          e.observations.each{|o|
            @sections["MEDICAL HISTORY"][o.concept.name.name] = (o.answer_string rescue "") if !o.concept.nil?
          }
        when "SOCIAL HISTORY"
          e.observations.each{|o|
            @sections["SOCIAL HISTORY"][o.concept.name.name] = (o.answer_string rescue "") if !o.concept.nil?
          }
        when "SURGICAL HISTORY"
          e.observations.each{|o|
            if !o.concept.nil?
              if @sections["SURGICAL HISTORY"][o.concept.name.name]
                @sections["SURGICAL HISTORY"][o.concept.name.name] += "; " + (o.answer_string rescue "") if !o.concept.nil?
              else
                @sections["SURGICAL HISTORY"][o.concept.name.name] = (o.answer_string rescue "") if !o.concept.nil?
              end   
            end
          }
        when "LAB RESULTS"
          e.observations.each{|o|
            if !o.concept.nil?
              if @sections["LAB RESULTS"][o.concept.name.name]
                if (o.answer_string rescue 0).to_i > 0
                  @sections["LAB RESULTS"][o.concept.name.name] = ((o.answer_string rescue 0).to_i > 
                      (@sections["LAB RESULTS"][o.concept.name.name].to_i) ? (o.answer_string rescue 0) : 
                      @sections["LAB RESULTS"][o.concept.name.name] )  if !o.concept.nil? 
                else
                  @sections["LAB RESULTS"][o.concept.name.name] = (o.answer_string rescue "") if !o.concept.nil?
                end
              else
                @sections["LAB RESULTS"][o.concept.name.name] = (o.answer_string rescue "") if !o.concept.nil?
              end   
            end
          }
        end
      end
    }
    
    @obstetrics_selected = false
    @medics_selected = false
    @social_selected = false
    @labs_selected = false
    
    # raise @sections.to_yaml
    
    @sections["OBSTETRIC HISTORY"].each{|o,a|
      case o.titleize
      when "Parity"
        if a.to_i > 4
          @obstetrics_selected = true
          break
        end
      when "Number Of Abortions"
        if a.to_i > 1
          @obstetrics_selected = true
          break
        end
      when "Condition At Birth"
        if a.titleize == "Still Birth"
          @obstetrics_selected = true
          break
        end
      when "Method Of Delivery"
        if a.titleize == "Caesarean Section"
          @obstetrics_selected = true
          break
        end
      when "Vacuum Extraction Delivery"
        if a.titleize == "Yes"
          @obstetrics_selected = true
          break
        end
      when "Symphysiotomy"
        if a.titleize == "Yes"
          @obstetrics_selected = true
          break
        end
      when "Hemorrhage"
        if a.upcase == "PPH"
          @obstetrics_selected = true
          break
        end
      when "Pre Eclampsia"
        if a.titleize == "Yes"
          @obstetrics_selected = true
          break
        end
      end
    }    
    
    if @sections["SURGICAL HISTORY"].length > 0
      @medics_selected = true
    end
    
    @sections["MEDICAL HISTORY"].each{|o,a|
      case o.titleize
      when "Asthma"
        if a.titleize == "Yes"
          @medics_selected = true
          break
        end
      when "Hypertension"
        if a.titleize == "Yes"
          @medics_selected = true
          break
        end
      when "Diabetes"
        if a.titleize == "Yes"
          @medics_selected = true
          break
        end
      when "Epilepsy"
        if a.titleize == "Yes"
          @medics_selected = true
          break
        end
      when "Renal Disease"
        if a.titleize == "Yes"
          @medics_selected = true
          break
        end
      when "Fistula Repair"
        if a.titleize == "Yes"
          @medics_selected = true
          break
        end
      when "Spine Or Leg Deform"
        if a.titleize == "Yes"
          @medics_selected = true
          break
        end
      end
    }   
    
    @sections["SOCIAL HISTORY"].each{|o,a|
      case o.titleize
      when "Patient Currently Smokes"
        if a.titleize == "Yes"
          @social_selected = true
          break
        end
      when "Patient Currently Consumes Alcohol"
        if a.titleize == "Yes"
          @social_selected = true
          break
        end
      when "Nutrition Status"
        if a.titleize == "Malnourished"
          @social_selected = true
          break
        end
      end
    }
    
    @sections["LAB RESULTS"].each{|o,a|
      case o.titleize
      when "Hb Test Result"
        if a.to_s.upcase != "NOT DONE" && a.to_i <= 11
          @labs_selected = true
          break
        end
      when "Syphilis Test Result"
        if a.to_s.upcase != "NOT DONE" && a.titleize == "Positive"
          @labs_selected = true
          break
        end
      when "Hiv Status"
        if a.to_s.upcase != "NOT DONE" && a.titleize == "Positive"
          @labs_selected = true
          break
        end
      end
    }
    
    # raise @labs_selected.to_yaml
    
    render :layout => 'dynamic-dashboard'
  end

  def treatment
    #@prescriptions = @patient.orders.current.prescriptions.all
    type = EncounterType.find_by_name('TREATMENT')
    session_date = session[:datetime].to_date rescue Date.today
    @prescriptions = Order.find(:all,
      :joins => "INNER JOIN encounter e USING (encounter_id)",
      :conditions => ["encounter_type = ? AND e.patient_id = ? AND DATE(encounter_datetime) = ?",
        type.id,@patient.id,session_date])
    @historical = @patient.orders.historical.prescriptions.all
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @prescriptions = restriction.filter_orders(@prescriptions)
      @historical = restriction.filter_orders(@historical)
    end
    render :template => 'dashboards/treatment', :layout => 'dashboard' 
  end

  def relationships
    if @patient.blank?
    	redirect_to :'clinic'
    	return
    else
      next_form = next_task(@patient)
      redirect_to next_form and return if next_form.match(/Reception/i)
		  @relationships = @patient.relationships rescue []
		  @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
		  @restricted.each do |restriction|
		    @relationships = restriction.filter_relationships(@relationships)
		  end
    	render :template => 'dashboards/relationships', :layout => 'dashboard' 
  	end
  end

  def problems
    render :template => 'dashboards/problems', :layout => 'dashboard' 
  end

  def personal
    render :template => 'dashboards/personal', :layout => 'dashboard' 
  end

  def history
    render :template => 'dashboards/history', :layout => 'dashboard' 
  end

  def programs
    @programs = @patient.patient_programs.all
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @programs = restriction.filter_programs(@programs)
    end
    flash.now[:error] = params[:error] unless params[:error].blank?
    render :template => 'dashboards/programs', :layout => 'dashboard' 
  end

  def graph
    render :template => "graphs/#{params[:data]}", :layout => false 
  end

  def void 
    @encounter = Encounter.find(params[:encounter_id])
    @patient = @encounter.patient
    @encounter.void
    # redirect_to "/patients/tab_visit_summary/?patient_id=#{@patient.id}" and return
    redirect_to "/patients/show/#{@patient.id}" and return
  end

  def print_registration
    print_and_redirect("/patients/national_id_label/?patient_id=#{@patient.id}", "/patients/demographics?patient_id=#{@patient.id}")  
  end

  def print_visit
    print_and_redirect("/patients/visit_label/?patient_id=#{@patient.id}", next_task(@patient))  
  end

  def print_mastercard_record
    print_and_redirect("/patients/mastercard_record_label/?patient_id=#{@patient.id}&date=#{params[:date]}", "/patients/visit?date=#{params[:date]}&patient_id=#{params[:patient_id]}")  
  end

  def national_id_label
    print_string = @patient.national_id_label rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a national id label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def visit_label
    print_string = @patient.visit_label rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a visit label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def mastercard_record_label
    print_string = @patient.visit_label(params[:date].to_date) 
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def mastercard
    #the parameter are used to re-construct the url when the mastercard is called from a Data cleaning report
    @quarter = params[:quarter]
    @arv_start_number = params[:arv_start_number]
    @arv_end_number = params[:arv_end_number]
    @show_mastercard_counter = false
    
    if params[:patient_id].blank?

      @show_mastercard_counter = true

      if !params[:current].blank?
        session[:mastercard_counter] = params[:current].to_i - 1
      end
      @prev_button_class = "yellow"
      @next_button_class = "yellow"
      if params[:current].to_i ==  1
        @prev_button_class = "gray"
      elsif params[:current].to_i ==  session[:mastercard_ids].length
        @next_button_class = "gray"
      else

      end
      @patient_id = session[:mastercard_ids][session[:mastercard_counter]]
      @data_demo = Mastercard.demographics(Patient.find(@patient_id))
      @visits = Mastercard.visits(Patient.find(@patient_id))

    elsif session[:mastercard_ids].length.to_i != 0
      @patient_id = params[:patient_id]
      @data_demo = Mastercard.demographics(Patient.find(@patient_id))
      @visits = Mastercard.visits(Patient.find(@patient_id))
    else
      @patient_id = params[:patient_id]
      @data_demo = Mastercard.demographics(Patient.find(@patient_id))
      @visits = Mastercard.visits(Patient.find(@patient_id))
    end
    render :layout => "menu"
  end
  
  def visit
    @patient_id = params[:patient_id] 
    @date = params[:date].to_date
    @patient = Patient.find(@patient_id)
    @visits = Mastercard.visits(@patient,@date)
    render :layout => "summary"
  end

  def next_available_arv_number
    next_available_arv_number = PatientIdentifier.next_available_arv_number
    render :text => next_available_arv_number.gsub(Location.current_arv_code,'').strip rescue nil
  end
  
  def assigned_arv_number
    assigned_arv_number = PatientIdentifier.find(:all,:conditions => ["voided = 0 AND identifier_type = ?",
        PatientIdentifierType.find_by_name("ARV Number").id]).collect{|i|
      i.identifier.gsub(Location.current_arv_code,'').strip.to_i
    } rescue nil
    render :text => assigned_arv_number.sort.to_json rescue nil 
  end

  def mastercard_modify
    if request.method == :get
      @patient_id = params[:id]
      case params[:field]
      when 'arv_number'
        @edit_page = "arv_number"
      when "name"
      end
    else
      @patient_id = params[:patient_id]
      case params[:field]
      when 'arv_number'
        type = params['identifiers'][0][:identifier_type]
        patient = Patient.find(params[:patient_id])
        patient_identifiers = PatientIdentifier.find(:all,
          :conditions => ["voided = 0 AND identifier_type = ? AND patient_id = ?",type.to_i,patient.id])

        patient_identifiers.map{|identifier|
          identifier.voided = 1
          identifier.void_reason = "given another number"
          identifier.date_voided  = Time.now()
          identifier.voided_by = User.current_user.id
          identifier.save
        }
              
        identifier = params['identifiers'][0][:identifier].strip
        if identifier.match(/(.*)[A-Z]/i).blank?
          params['identifiers'][0][:identifier] = "#{Location.current_arv_code} #{identifier}"
        end
        patient.patient_identifiers.create(params[:identifiers])
        redirect_to :action => "mastercard",:patient_id => patient.id and return
      when "name"
      end
    end
  end

  def summary
    @encounter_type = params[:skipped]
    @patient_id = params[:patient_id]
    render :layout => "menu"
  end

  def export_to_csv
    @users = User.find(:all)

    csv_string = FasterCSV.generate do |csv|
      # header row
      csv << ["id", "first_name", "last_name"]

      # data rows
      @users.each do |user|
        csv << [user.id, user.username, user.salt]
      end
    end

    # send it to the browsah
    send_data csv_string,
      :type => 'text/csv; charset=iso-8859-1; header=present',
      :disposition => "attachment; filename=users.csv"
  end
   
  def tab_visit_summary
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    
    @encounters = @patient.encounters.active.find(:all, 
      :conditions => ["DATE(encounter_datetime) = ?", (session[:datetime] ? session[:datetime].to_date : Date.today)]) rescue []
    
    @encounter_names = @encounters.map{|encounter| encounter.name}.uniq rescue []
    
    @encounter_names = @encounter_names.reverse

    render :layout => false
  end

  def tab_obstetric_history
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
     
    @pregnancies = Patient.active_range(@patient.id)
    
    @range = []
    
    @pregnancies = @pregnancies[1]
    
    @pregnancies.each{|preg|
      @range << preg[0].to_date
    }
    
    
    @encs = (Encounter.active.find(:all, :conditions => ["patient_id = ? AND encounter_type = ?", 
          @patient.id, EncounterType.find_by_name("OBSTETRIC HISTORY").id]) rescue []).length
    
    if @encs > 0
      @deliveries = Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
          Encounter.active.find(:all).collect{|e| e.encounter_id},
          ConceptName.find_by_name('PARITY').concept_id]).answer_string.to_i rescue nil

      @deliveries = @deliveries + (@range.length > 0 ? @range.length - 1 : @range.length) if !@deliveries.nil?
    
      @gravida = Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
          Encounter.active.find(:all).collect{|e| e.encounter_id},
          ConceptName.find_by_name('GRAVIDA').concept_id]).answer_string.to_i rescue nil

      @multipreg = Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
          Encounter.active.find(:all, :conditions => ["encounter_type = ?", 
              EncounterType.find_by_name("OBSTETRIC HISTORY").id]).collect{|e| e.encounter_id},
          ConceptName.find_by_name('MULTIPLE GESTATION').concept_id]).answer_string.upcase rescue nil

      @abortions = Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
          Encounter.active.find(:all).collect{|e| e.encounter_id},
          ConceptName.find_by_name('NUMBER OF ABORTIONS').concept_id]).answer_string.to_i rescue nil

      @stillbirths = Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
          Encounter.active.find(:all).collect{|e| e.encounter_id},
          ConceptName.find_by_name('STILL BIRTH').concept_id]).answer_string.upcase rescue nil

      @csections = Encounter.active.find(:all, :conditions => ["patient_id = ? AND encounter_type = ?", 
          @patient.id, EncounterType.find_by_name("OBSTETRIC HISTORY").id]).collect{|e| 
        e.observations.collect{|o| o.answer_string if o.answer_string.match(/caesarean\ssection/i)}
      }.flatten.delete_if{|x| x.nil?}.length rescue nil

      @vacuum = Encounter.active.find(:all, :conditions => ["patient_id = ? AND encounter_type = ?", 
          @patient.id, EncounterType.find_by_name("OBSTETRIC HISTORY").id]).collect{|e| 
        e.observations.collect{|o| o.answer_string if o.answer_string.match(/Vacuum\sextraction\sdelivery/i)}
      }.flatten.delete_if{|x| x.nil?}.length rescue nil
      
      @symphosio = Observation.find(:last, 
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
          Encounter.active.find(:all).collect{|e| e.encounter_id},
          ConceptName.find_by_name('SYMPHYSIOTOMY').concept_id]).answer_string.upcase rescue nil

      @haemorrhage = Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
          Encounter.active.find(:all).collect{|e| e.encounter_id},
          ConceptName.find_by_name('HEMORRHAGE').concept_id]).answer_string.upcase rescue nil

      @preeclampsia = Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
          Encounter.active.find(:all).collect{|e| e.encounter_id},
          ConceptName.find_by_name('PRE-ECLAMPSIA').concept_id]).answer_string.upcase rescue nil

      @eclampsia = Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
          Encounter.active.find(:all).collect{|e| e.encounter_id},
          ConceptName.find_by_name('ECLAMPSIA').concept_id]).answer_string.upcase rescue nil
    end
    
    render :layout => false
  end

  def tab_medical_history
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    
    @asthma = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('ASTHMA').concept_id]).answer_string.upcase rescue nil

    @hyper = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('HYPERTENSION').concept_id]).answer_string.upcase rescue nil

    @diabetes = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('DIABETES').concept_id]).answer_string.upcase rescue nil

    @epilepsy = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('EPILEPSY').concept_id]).answer_string.upcase rescue nil

    @renal = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('RENAL DISEASE').concept_id]).answer_string.upcase rescue nil

    @fistula = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('FISTULA REPAIR').concept_id]).answer_string.upcase rescue nil

    @deform = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('SPINE OR LEG DEFORM').concept_id]).answer_string.upcase rescue nil

    @surgicals = Observation.find(:all, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all, :conditions => ["patient_id = ? AND encounter_type = ?", 
            @patient.id, EncounterType.find_by_name("SURGICAL HISTORY").id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('PROCEDURE DONE').concept_id]).collect{|o| 
      "#{o.answer_string} (#{o.obs_datetime.strftime('%d-%b-%Y')})"} rescue []

    @age = @patient.age rescue 0

    render :layout => false
  end    

  def tab_examinations_management
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil

    @height = @patient.current_height.to_i

    @multiple = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('EVER HAD A MULTIPLE PREGNANCY?').concept_id]).answer_string rescue nil

    @who = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('WHO CLINICAL STAGE').concept_id]).answer_string.to_i rescue nil

    render :layout => false
  end

  def tab_lab_results
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil

    syphil = {}
    @patient.encounters.find(:all, :conditions => ["encounter_type IN (?)", 
        EncounterType.find_by_name("LAB RESULTS").id]).each{|e| 
      e.observations.active.each{|o| 
        syphil[o.concept.name.name.upcase] = o.answer_string.upcase
      }      
    }
    
    @syphilis = syphil["SYPHILIS TEST RESULT"].titleize rescue nil

    @syphilis_date = syphil["SYPHILIS TEST RESULT DATE"] rescue nil

    @hiv_test = syphil["HIV STATUS"].titleize rescue nil

    @hiv_test_date = syphil["HIV TEST DATE"] rescue nil

    hb = {}; pos = 1; 
    
    @patient.encounters.active.find(:all, 
      :order => "encounter_datetime DESC", :conditions => ["encounter_type = ?", 
        EncounterType.find_by_name("LAB RESULTS").id]).each{|e| 
      e.observations.active.each{|o| hb[o.concept.name.name.upcase + " " + 
            pos.to_s] = o.answer_string.upcase; pos += 1 if o.concept.name.name.upcase == "HB TEST RESULT DATE";
      }      
    }
    
    @hb1 = hb["HB TEST RESULT 2"] rescue nil

    @hb1_date = hb["HB TEST RESULT DATE 2"] rescue nil

    @hb2 = hb["HB TEST RESULT 1"] rescue nil

    @hb2_date = hb["HB TEST RESULT DATE 1"] rescue nil

    @cd4 = syphil['CD4 COUNT'] rescue nil

    @cd4_date = syphil['CD4 COUNT DATETIME'] rescue nil

    @height = @patient.current_height.to_i

    @multiple = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all, :conditions => ["encounter_type = ?", 
            EncounterType.find_by_name("CURRENT PREGNANCY").id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('Multiple Gestation').concept_id]).answer_string rescue nil

    @who = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('WHO STAGE').concept_id]).answer_string.to_i rescue nil

    render :layout => false
  end

  def tab_visit_history
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
  
    @current_range = Patient.active_range(@patient.id, (params[:target_date] ? 
          params[:target_date].to_date : (session[:datetime] ? session[:datetime].to_date : Date.today)))

    # raise @current_range.to_yaml
    
    @encounters = {}

    @patient.encounters.active.find(:all, :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ?", 
        @current_range[0]["START"], @current_range[0]["END"]]).collect{|e|       
      @encounters[e.encounter_datetime.strftime("%d/%b/%Y")] = {"USER" => User.find(e.creator).name }
    }

    @patient.encounters.active.find(:all, :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ?", 
        @current_range[0]["START"], @current_range[0]["END"]]).collect{|e| 
      @encounters[e.encounter_datetime.strftime("%d/%b/%Y")][e.type.name.upcase] = ({} rescue "") if !e.type.nil?
    }

    @patient.encounters.active.find(:all, :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ?", 
        @current_range[0]["START"], @current_range[0]["END"]]).collect{|e| 
      if !e.type.nil?       
        e.observations.each{|o| 
          if o.to_a[0]
            if o.to_a[0].upcase == "DIAGNOSIS" && @encounters[e.encounter_datetime.strftime("%d/%b/%Y")][e.type.name.upcase][o.to_a[0].upcase]
              @encounters[e.encounter_datetime.strftime("%d/%b/%Y")][e.type.name.upcase][o.to_a[0].upcase] += "; " + o.to_a[1]
            else
              @encounters[e.encounter_datetime.strftime("%d/%b/%Y")][e.type.name.upcase][o.to_a[0].upcase] = o.to_a[1]
              if o.to_a[0].upcase == "PLANNED DELIVERY PLACE"
                @current_range[0]["PLANNED DELIVERY PLACE"] = o.to_a[1]
              elsif o.to_a[0].upcase == "MOSQUITO NET"
                @current_range[0]["MOSQUITO NET"] = o.to_a[1]
              end
            end
          end
        }
      end
    }

    @drugs = {}; 
    @other_drugs = {}; 
    main_drugs = ["TTV", "SP", "Fefol", "NVP", "TDF/3TC/EFV"]
    
    @patient.encounters.active.find(:all, :order => "encounter_datetime DESC", 
      :conditions => ["encounter_type = ? AND encounter_datetime >= ? AND encounter_datetime <= ?", 
        EncounterType.find_by_name("TREATMENT").id, @current_range[0]["START"], @current_range[0]["END"]]).each{|e| 
      @drugs[e.encounter_datetime.strftime("%d/%b/%Y")] = {} if !@drugs[e.encounter_datetime.strftime("%d/%b/%Y")]; 
      @other_drugs[e.encounter_datetime.strftime("%d/%b/%Y")] = {} if !@other_drugs[e.encounter_datetime.strftime("%d/%b/%Y")]; 
      e.orders.each{|o| 
        if main_drugs.include?(o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")])          
          if o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")] == "NVP"
            if o.drug_order.drug.name.upcase.include?("ML")
              @drugs[e.encounter_datetime.strftime("%d/%b/%Y")][o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")]] = o.drug_order.amount_needed
            else
              @other_drugs[e.encounter_datetime.strftime("%d/%b/%Y")][o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")]] = o.drug_order.amount_needed
            end
          else            
            @drugs[e.encounter_datetime.strftime("%d/%b/%Y")][o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")]] = o.drug_order.amount_needed
          end          
        else
          @other_drugs[e.encounter_datetime.strftime("%d/%b/%Y")][o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")]] = o.drug_order.amount_needed
        end
      }      
    }
    
    render :layout => false
  end

  def observations
    @patient = Patient.find(params[:patient_id]) rescue nil
  end

  def preventative_medications
    @patient = Patient.find(params[:patient_id]) rescue nil
  end

  def hiv_status
    @patient = Patient.find(params[:patient_id]) rescue nil
    
    @current_range = Patient.active_range(@patient.id, (session[:datetime] ? session[:datetime].to_date : Date.today)) # rescue nil

    @encounters = @patient.encounters.active.find(:all, :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ?", 
        @current_range[0]["START"], @current_range[0]["END"]]) rescue []
    
    @encounter_names = @patient.encounters.active.find(:all, :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ?", 
        @current_range[0]["START"], @current_range[0]["END"]]).map{|encounter| encounter.name}.uniq rescue []

    @names = @encounters.collect{|e|
      e.name.upcase
    }
    
    # raise @encounters.to_yaml        
    
    @lmp = nil
    @planned_place = nil
    @multi_preg = nil
    @bed_net = nil
    @bed_net_date = nil
    @tt = nil
    @f_visit = nil
    @enc_id = nil
    
    @encounters.each{|e|
      if e.name.upcase == "CURRENT PREGNANCY"
        @enc_id = e.id
        
        e.observations.each{|o| 
          if !o.concept.nil?
            @lmp = (o.answer_string.to_date.strftime("%Y-%m-%d") rescue nil) if o.concept.name.name.upcase == "DATE OF LAST MENSTRUAL PERIOD"
            @planned_place = (o.answer_string rescue nil) if o.concept.name.name.titleize == "Planned Delivery Place"
            @multi_preg = (o.answer_string rescue nil) if o.concept.name.name.titleize == "Multiple Gestation"
            @bed_net = (o.answer_string rescue nil) if o.concept.name.name.titleize == "Mosquito Net"
            @bed_net_date = (o.answer_string rescue nil) if o.concept.name.name.titleize == "Date"
            @tt = (o.answer_string.to_i rescue nil) if o.concept.name.name.titleize == "Tt Status"
            @f_visit = (o.answer_string rescue nil) if o.concept.name.name.titleize == "Week Of First Visit"
          end
        }
      end
    }
    
  end

  def pmtct_management
    @patient = Patient.find(params[:patient_id]) rescue nil
  end

  def obstetric_history
    @patient = Patient.find(params[:patient_id]) rescue nil
  end

  def medical_history
    @patient = Patient.find(params[:patient_id]) rescue nil
  end

  def examinations_management
    @patient = Patient.find(params[:patient_id]) rescue nil
  end

  def new
    @patient = Patient.find(params[:patient_id] || session[:patient_id])
  end

  def pregnancy_history
    @patient = Patient.find(params[:patient_id]) rescue nil
    
    @pregnancies = Patient.active_range(@patient.id)
    
    @range = []
    
    @pregnancies = @pregnancies[1]
    
    @pregnancies.each{|preg|
      @range << preg[0].to_date
    }
    
    @range = @range.sort.reverse
    
    @gravida = Observation.find(:last,
      :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
        Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('GRAVIDA').concept_id]).answer_string.to_i rescue nil

    # raise @range.to_yaml
    
    render :layout => 'dashboard'
  end

  def current_pregnancy
    @patient = Patient.find(params[:patient_id]) rescue nil
  end

  def outcome
    @patient = Patient.find(params[:patient_id]) rescue nil
  end

  def current_visit
    @patient = Patient.find(params[:patient_id] || session[:patient_id])
    
    @current_range = Patient.active_range(@patient.id, (session[:datetime] ? session[:datetime].to_date : Date.today)) # rescue nil

    @encounters = @patient.encounters.active.find(:all, :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ?", 
        @current_range[0]["START"], @current_range[0]["END"]]) rescue []
    
    @names = @encounters.collect{|e|
      e.name.upcase
    }.uniq
    
    @encounters = @patient.encounters.active.find(:all, :conditions => ["encounter_type IN (?) AND " + 
          "DATE_FORMAT(encounter_datetime, '%Y-%m-%d') = ?",
        EncounterType.find(:all, :conditions => ["name in ('OBSERVATIONS', 'VITALS', 'TREATMENT', 'LAB RESULTS', " +
              "'DIAGNOSIS', 'APPOINTMENT', 'UPDATE OUTCOME')"]).collect{|t| t.id}, 
        (session[:datetime] ? session[:datetime].to_date.strftime("%Y-%m-%d") : Date.today.strftime("%Y-%m-%d"))]).collect{|e|              
      e.type.name
    }.join(", ") # rescue ""

    @all_encounters = @patient.encounters.active.find(:all, :conditions => ["encounter_type IN (?)",
        EncounterType.find(:all, :conditions => ["name in ('OBSERVATIONS', 'VITALS', 'TREATMENT', 'LAB RESULTS', " +
              "'DIAGNOSIS', 'APPOINTMENT', 'UPDATE OUTCOME')"]).collect{|t| t.id}]).collect{|e|              
      e.type.name
    }.join(", ") # rescue ""

  end

  def demographics
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    @national_id = @patient.national_id_with_dashes rescue nil

    @first_name = @patient.person.names.first.given_name rescue nil
    @last_name = @patient.person.names.first.family_name rescue nil
    @birthdate = @patient.person.birthdate_formatted rescue nil
    @gender = @patient.person.sex rescue ''

    @current_village = @patient.person.addresses.first.city_village rescue ''
    @current_ta = @patient.person.addresses.first.county_district rescue ''
    @current_district = @patient.person.addresses.first.state_province rescue ''
    @home_district = @patient.person.addresses.first.address2 rescue ''

    @primary_phone = @patient.person.phone_numbers[:cell_phone_number] # rescue ''
    @secondary_phone = @patient.person.phone_numbers["Home Phone Number"] rescue ''

    @occupation = @patient.person.get_attribute("occupation") rescue ''
    render :template => 'patients/demographics', :layout => 'menu'

  end

  def edit_demographics
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    @field = params[:field]
    render :partial => "edit_demographics", :field =>@field, :layout => true and return
  end

  def update_demographics
    Person.update_demographics(params)
    redirect_to :action => 'demographics', :patient_id => params['person_id'] and return
  end

  def patient_history
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    
    @encounters = @patient.encounters.active.collect{|e| e.name}
  end

  def tab_detailed_obstetric_history
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    
    @obstetrics = {}
    search_set = ["YEAR OF BIRTH", "PLACE OF BIRTH", "PREGNANCY", "LABOUR DURATION", 
      "METHOD OF DELIVERY", "CONDITION AT BIRTH", "BIRTH WEIGHT", "ALIVE", 
      "AGE AT DEATH", "UNITS OF AGE OF CHILD", "PROCEDURE DONE"]
    current_level = 0
    
    (Encounter.find(:all, :conditions => ["encounter_type = ? AND patient_id = ?", 
          EncounterType.find_by_name("OBSTETRIC HISTORY").id, @patient.id]) rescue []).each{|e|
      e.observations.active.each{|obs|
        concept = obs.concept.name.name rescue nil
        if(!concept.nil?)
          if search_set.include?(concept.upcase)
            if obs.concept.name.name.upcase.eql?("YEAR OF BIRTH")
              current_level += 1
            
              @obstetrics[current_level] = {}
            end
          
            if @obstetrics[current_level]
              @obstetrics[current_level][concept.upcase] = obs.answer_string rescue nil
              
              if concept.upcase == "YEAR OF BIRTH" && obs.answer_string.to_i == 0
                @obstetrics[current_level][concept.upcase] = "Unknown"
              end
            end
                        
          end
        end
      }      
    }
    
    # raise @obstetrics.to_yaml
    
    @pregnancies = Patient.active_range(@patient.id)
    
    @range = []
    
    @pregnancies = @pregnancies[1]
    
    @pregnancies.each{|preg|
      @range << preg[0].to_date
    }
    
    @range = @range.sort    
    
    @range.each{|y|
      current_level += 1
      @obstetrics[current_level] = {}
      @obstetrics[current_level]["YEAR OF BIRTH"] = y.year
      @obstetrics[current_level]["PLACE OF BIRTH"] = "<b>(Here)</b>"
    }
    
    render :layout => false
  end
  
  def activated_range(patient_id, date = (session[:datetime] ? session[:datetime].to_date : Date.today))    
    patient = Patient.find(patient_id) rescue nil
    
    current_range = {}
    
    active_date = date
      
    pregnancies = {}; 
    
    patient.encounters.active.find(:all, :order => ["encounter_datetime DESC"]).each{|e| 
      if e.name == "CURRENT PREGNANCY" && !pregnancies[e.encounter_datetime.strftime("%Y-%m-%d")]
        pregnancies[e.encounter_datetime.strftime("%Y-%m-%d")] = {}  
        e.observations.each{|o| 
          concept = o.concept.name rescue nil
          if concept
            if o.concept.name.name == "DATE OF LAST MENSTRUAL PERIOD"         
              pregnancies[e.encounter_datetime.strftime("%Y-%m-%d")][o.concept.name.name] = o.answer_string 
            end
          end
        } 
      end      
    }    
    
    pregnancies.each{|preg|
      if preg[1]["DATE OF LAST MENSTRUAL PERIOD"]
        preg[1]["START"] = preg[1]["DATE OF LAST MENSTRUAL PERIOD"].to_date
        preg[1]["END"] = preg[1]["DATE OF LAST MENSTRUAL PERIOD"].to_date + 45.week
      else
        preg[1]["START"] = preg[0].to_date
        preg[1]["END"] = preg[0].to_date + 45.week
      end
      
      if active_date >= preg[1]["START"] && active_date <= preg[1]["END"]
        current_range["START"] = preg[1]["START"]
        current_range["END"] = preg[1]["END"]
      end
    }
    
    return [current_range, pregnancies]
  end
  
  def number_of_booked_patients
    date = params[:date].to_date rescue Date.today
    encounter_type = EncounterType.find_by_name('APPOINTMENT')
    concept_id = ConceptName.find_by_name('APPOINTMENT DATE').concept_id
    count = Observation.count(:all,
      :joins => "INNER JOIN encounter e USING(encounter_id)",:group => "value_datetime",
      :conditions =>["concept_id = ? AND encounter_type = ? AND value_datetime >= ? AND value_datetime <= ?",
        concept_id,encounter_type.id,date.strftime('%Y-%m-%d 00:00:00'),date.strftime('%Y-%m-%d 23:59:59')])
    count = count.values unless count.blank?
    count = '0' if count.blank?
    render :text => count
  end

  def tab_social_history
    @alcohol = nil
    @smoke = nil
    @nutrition = nil
    
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    
    @alcohol = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('Patient currently consumes alcohol').concept_id]).answer_string rescue nil

    @smokes = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('Patient currently smokes').concept_id]).answer_string rescue nil

    @nutrition = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('Nutrition status').concept_id]).answer_string rescue nil
  
    @civil = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('Civil status').concept_id]).answer_string.titleize rescue nil
  
    @civil_other = (Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
          @patient.id, Encounter.active.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
          ConceptName.find_by_name('Other Civil Status Comment').concept_id]).answer_string rescue nil) if @civil == "Other"
  
    @religion = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('Religion').concept_id]).answer_string.titleize rescue nil
  
    @religion_other = (Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
          @patient.id, Encounter.active.find(:all, :conditions => ["patient_id = ? AND encounter_type = ?", 
              @patient.id, EncounterType.find_by_name("SOCIAL HISTORY").id]).collect{|e| e.encounter_id},
          ConceptName.find_by_name('Other').concept_id]).answer_string rescue nil) if @religion == "Other"
  
    render :layout => false
  end
  
  def print_history
    print_and_redirect("/patients/obstertic_medical_examination_label/?patient_id=#{@patient.id}", 
      "/patients/patient_history/?patient_id=#{@patient.id}")  
  end

  def obstertic_medical_examination_label
    print_string = @patient.obstetric_medical_history_label + @patient.detailed_obstetric_history_label rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate an obstetric and medical history label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def print_visit_label
    print_and_redirect("/patients/current_visit_label/?patient_id=#{@patient.id}", 
      "/patients/current_visit/?patient_id=#{@patient.id}")  
  end

  def current_visit_label
    print_string = @patient.visit_summary_label((session[:datetime] ? session[:datetime].to_date : Date.today)) + 
      @patient.visit_summary2_label((session[:datetime] ? session[:datetime].to_date : Date.today)) # rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate an obstetric and medical history label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def print_exam_label
    print_and_redirect("/patients/exam_label/?patient_id=#{@patient.id}", 
      "/patients/current_visit/?patient_id=#{@patient.id}")  
  end

  def exam_label
    print_string = @patient.examination_label rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate an obstetric and medical history label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def print_labels
    @patient = Patient.find(params[:patient_id] || session[:patient_id])
  end
  
  def visit_type
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil    
  end
  
  def social_history
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil 
    
    religions = ["Jehovahs Witness",  
      "Roman Catholic", 
      "Presbyterian (C.C.A.P.)",
      "Seventh Day Adventist", 
      "Baptist", 
      "Moslem",
      "Other"]
    
    @religions = Observation.find(:all, :joins => [:concept, :encounter], 
      :conditions => ["obs.concept_id = ? AND NOT value_text IN (?) AND " + 
          "encounter_type = ?", 
        ConceptName.find_by_name("Other").concept_id, religions, 
        EncounterType.find_by_name("SOCIAL HISTORY").id]).collect{|o| o.value_text}
    
    @religions = religions + @religions
    
    # raise @religions.to_yaml
  end

  def confirm
    
    session_date = (session[:datetime].to_date rescue Date.today)
    @latest_lmp = @patient.lmp(session_date)
  
    params[:url] += "&from_confirmation=true"

    @current_pregnancy = @patient.encounters.find(:last,
      :conditions => ["encounter_type = ? AND voided = 0 AND DATE(encounter_datetime) BETWEEN ? AND ?",
        EncounterType.find_by_name("CURRENT PREGNANCY"), session_date.to_date - 10.months, session_date.to_date])

    @data = {}

    if @current_pregnancy.present?
     
      @data["LMP"] =  @patient.lmp(session_date).strftime("%d/%b/%Y") rescue nil
      @data["FUNDUS"] = @patient.fundus_by_lmp(session_date) rescue nil
     
      @data["ANC VISITS"] = @patient.anc_visits(@patient, session_date).blank? ? nil : @patient.anc_visits(@patient, session_date).uniq

      #disregard irrelevant pregnancies
      if ((@data["LMP"].present? and @data["LMP"].to_date + 10.months < session_date) rescue true)
        @data = {}
      end

    end

  end
  
  def verify_route
    redirect_to next_task(@patient) and return
  end

  private

end
