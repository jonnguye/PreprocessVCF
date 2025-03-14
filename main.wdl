version 1.0

workflow PreprocessVCF {
    input {
        File input_vcf
        File input_vcf_index
        File ancestry_labels
        String min_allele_count
    }

    # Define the constant array of chromosomes
    Array[String] chromosomes = ["chr1", "chr2", "chr3", "chr4", "chr5", "chr6", "chr7", "chr8", "chr9", "chr10", 
                                  "chr11", "chr12", "chr13", "chr14", "chr15", "chr16", "chr17", "chr18", 
                                  "chr19", "chr20", "chr21", "chr22", "chrX", "chrY"]

    # Scatter across chromosomes
    scatter(chromosome in chromosomes) {
        call ProcessChromosome {
            input:
                vcf_file = input_vcf,
                vcf_file_index = input_vcf_index,
                ancestry_labels = ancestry_labels,
                min_allele_count = min_allele_count,
                chromosome = chromosome
        }
    }

    # Final step to gather results
    call GatherResults {
        input:
            chromosome_results = ProcessChromosome.vcf_output,
            indices = ProcessChromosome.vcf_output_index
    }
}

# Task to process each chromosome
task ProcessChromosome {
    input {
        File vcf_file
        File vcf_file_index
        File ancestry_labels
        String min_allele_count
        String chromosome

        String docker = "quay.io/biocontainers/bcftools:1.21--h3a4d415_1"
        Int cpu = 1
        Int memory_gb = ceil(size(vcf_file, "GB") + 8)
        Int disk_size = ceil(size(vcf_file, "GB") + 20)
    }

    command {
        # Use bcftools to filter the VCF for the specific chromosome
        bcftools view -r ${chromosome} ${vcf_file} -Ou \
        | bcftools norm -m + - \
        | bcftools view -m2 -M2 -c${min_allele_count} - \
        | bcftools +fill-tags -  -- -t AN,AC,AF,MAF,AC_hom,AC_het,HWE,F_MISSING -S ${ancestry_labels} \
        | bcftools view -e "F_MISSING > 0.05" -W -Oz -o ${chromosome}.filtered.vcf.gz
    }
    
    runtime {
        docker: docker
        memory: memory_gb + ' GB'
        cpu: cpu
        disk: disk_size + ' GB'
    }
    
    output {
        File vcf_output = "${chromosome}.filtered.vcf.gz"
        File vcf_output_index = "${chromosome}.filtered.vcf.gz.csi"
    }
}

# Task to gather results (optional, depending on your needs)
task GatherResults {
    input {
        Array[File] chromosome_results
        Array[File] indices

        String docker = "quay.io/biocontainers/bcftools:1.21--h3a4d415_1"
        Int cpu = 4
        Int memory_gb = 64
        Int disk_size = ceil(size(chromosome_results, "GB") + 20)
    }

    command {
        # Combine the filtered VCFs into one file (optional)
        bcftools concat --threads ~{cpu - 1} -Oz -o combined.vcf.gz ~{sep=' ' chromosome_results}
    }
    
    runtime {
        docker: docker
        memory: memory_gb + ' GB'
        cpu: cpu
        disk: disk_size + ' GB'
    }
    
    output {
        File combined_vcf = "combined.vcf.gz"
    }
}










