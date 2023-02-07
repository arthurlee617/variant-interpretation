version 1.0

##########################################################################################

## Github commit: talkowski-lab/gatk-sv-v1:<ENTER HASH HERE IN FIRECLOUD>

##########################################################################################

import "igvTrioPlots.wdl" as igv
import "Structs.wdl"

workflow IGV_all_samples {
    input {
        #Array[String] pb_list
        #Array[String] fa_list
        #Array[String] mo_list
        #Array[File] pb_cram_list
        #Array[File] pb_crai_list
        #Array[File] fa_cram_list
        #Array[File] fa_crai_list
        #Array[File] mo_cram_list
        #Array[File] mo_crai_list
        Array[String] fam_ids
        File ped_file
        File sample_cram
        File varfile
        File Fasta
        File Fasta_dict
        File Fasta_idx
        File nested_repeats
        File simple_repeats
        File empty_track
        String prefix
        String sv_base_mini_docker
        String igv_docker
        RuntimeAttr? runtime_attr_override
    }

    scatter (fam_id in fam_ids){
        call generate_per_family_bed{
            input:
                varfile = varfile,
                fam_id = fam_id,
                ped_file = ped_file,
                sv_base_mini_docker=sv_base_mini_docker,
                runtime_attr_override=runtime_attr_override
        }

        call igv.IGV_trio as IGV_trio {
            input:
                varfile=generate_per_family_bed.per_family_varfile,
                Fasta = Fasta,
                Fasta_idx = Fasta_idx,
                Fasta_dict = Fasta_dict,
                nested_repeats = nested_repeats,
                simple_repeats = simple_repeats,
                empty_track = empty_track,
                fam_id = fam_id,
                ped_file = ped_file,
                sample_cram = sample_cram,
                igv_docker = igv_docker
                }
        }
    call integrate_igv_plots{
        input:
            igv_tar = IGV_trio.tar_gz_pe,
            prefix = prefix, 
            sv_base_mini_docker = sv_base_mini_docker
    }

    output{
        File tar_gz_pe = integrate_igv_plots.plot_tar
    }
    }


task generate_per_family_bed{
    input {
        File varfile
        String fam_id
        File ped_file
        String sv_base_mini_docker
        RuntimeAttr? runtime_attr_override
    }
    RuntimeAttr default_attr=object {
        cpu: 1,
        mem_gb: 1,
        disk_gb: 10,
        boot_disk_gb: 10,
        preemptible: 1,
        max_retries: 1
    }

    String filename = basename(varfile, ".bed")
    command <<<
        set -euo pipefail
        cat ~{varfile} | gunzip | cut -f1-5 > updated_varfile_1.bed
        cat ~{varfile} | gunzip | csvcut -t -c sample > updated_varfile_2.bed
        paste updated_varfile_1.bed updated_varfile_2.bed > updated_varfile.bed
        grep ~{fam_id} ~{ped_file} | cut -f2 > sample_ids.txt
        grep -f sample_ids.txt updated_varfile.bed | cut -f1-5 | awk '{print $1,$2,$3,$4,$5}' | sed -e 's/ /\t/g' > ~{filename}.~{fam_id}.bed
        >>>

    output{
        File per_family_varfile= "~{filename}.~{fam_id}.bed"
    }

    RuntimeAttr runtime_attr = select_first([runtime_attr_override, default_attr])
    runtime {
        cpu: select_first([runtime_attr.cpu, default_attr.cpu])
        memory: select_first([runtime_attr.mem_gb, default_attr.mem_gb]) + " GiB"
        disks: "local-disk " + select_first([runtime_attr.disk_gb, default_attr.disk_gb]) + " HDD"
        bootDiskSizeGb: select_first([runtime_attr.boot_disk_gb, default_attr.boot_disk_gb])
        docker: sv_base_mini_docker
        preemptible: select_first([runtime_attr.preemptible, default_attr.preemptible])
        maxRetries: select_first([runtime_attr.max_retries, default_attr.max_retries])
  }

    }

task integrate_igv_plots{
    input {
        Array[File] igv_tar
        String prefix
        String sv_base_mini_docker
        RuntimeAttr? runtime_attr_override
    }
    RuntimeAttr default_attr=object {
        cpu: 1,
        mem_gb: 1,
        disk_gb: 10,
        boot_disk_gb: 10,
        preemptible: 1,
        max_retries: 1
    }

    command <<<
        mkdir ~{prefix}_igv_plots
        while read file; do
            tar -zxf ${file}
            mv pe_igv_plots/*  ~{prefix}_igv_plots/
        done < ~{write_lines(igv_tar)};
        tar -czf ~{prefix}_igv_plots.tar.gz ~{prefix}_igv_plots
    >>>

    output{
        File plot_tar = "~{prefix}_igv_plots.tar.gz"
    }

    RuntimeAttr runtime_attr = select_first([runtime_attr_override, default_attr])

    runtime {
        cpu: select_first([runtime_attr.cpu, default_attr.cpu])
        memory: select_first([runtime_attr.mem_gb, default_attr.mem_gb]) + " GiB"
        disks: "local-disk " + select_first([runtime_attr.disk_gb, default_attr.disk_gb]) + " HDD"
        bootDiskSizeGb: select_first([runtime_attr.boot_disk_gb, default_attr.boot_disk_gb])
        docker: sv_base_mini_docker
        preemptible: select_first([runtime_attr.preemptible, default_attr.preemptible])
        maxRetries: select_first([runtime_attr.max_retries, default_attr.max_retries])
  }

    }