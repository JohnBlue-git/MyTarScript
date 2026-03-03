#!/usr/bin/env python3
"""
Pytest test suite for my_tar.sh script
Tests archive creation, extraction, compression, and selective file handling
"""

import pytest
import subprocess
import os
import tempfile
import shutil
from pathlib import Path


class TestMyTar:
    """Test suite for my_tar.sh bash script"""

    @pytest.fixture(autouse=True)
    def setup_teardown(self):
        """Setup and teardown for each test"""
        # Setup: Create temporary directory for archives only
        self.test_dir = tempfile.mkdtemp(prefix="my_tar_test_")
        self.original_dir = os.getcwd()

        # Get the project root and script path
        self.project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        self.script_path = os.path.join(self.project_root, "my_tar.sh")

        # Use existing files directory instead of creating new one
        self.test_files_dir = os.path.join(self.project_root, "files")

        # Ensure files directory has content, if empty add test files
        self._ensure_test_files()

        yield

        # Teardown: Remove temporary directory (but keep files dir)
        os.chdir(self.original_dir)
        shutil.rmtree(self.test_dir, ignore_errors=True)
    
    def _ensure_test_files(self):
        """Ensure test files exist in the files directory"""
        # Ensure directories exist
        for dir_name in ["default", "develop", "release"]:
            dir_path = os.path.join(self.test_files_dir, dir_name)
            os.makedirs(dir_path, exist_ok=True)

            # Add sample file if directory is empty
            sample_file = os.path.join(dir_path, f"{dir_name}_file.txt")
            if not os.path.exists(sample_file):
                with open(sample_file, "w") as f:
                    f.write(f"Content of {dir_name}")

        # Ensure XML files exist
        for xml_name in ["default.xml", "develop.xml", "release.xml"]:
            xml_path = os.path.join(self.test_files_dir, xml_name)
            if not os.path.exists(xml_path):
                with open(xml_path, "w") as f:
                    f.write(f"<?xml version='1.0'?>\n<{xml_name.replace('.xml', '')}/>")

        # Create additional file for skip testing (in temp dir to not pollute files/)
        skip_test_file = os.path.join(self.test_dir, "skip_me.txt")
        with open(skip_test_file, "w") as f:
            f.write("This should be skipped")

    def _run_script(self, args, expect_success=True):
        """Helper to run the bash script"""
        cmd = ["bash", self.script_path] + args
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True
        )

        if expect_success:
            if result.returncode != 0:
                print(f"STDOUT: {result.stdout}")
                print(f"STDERR: {result.stderr}")
            assert result.returncode == 0, f"Script failed: {result.stderr}"

        return result
    
    def test_script_exists(self):
        """Test that the script file exists and is executable"""
        assert os.path.exists(self.script_path), f"Script not found at {self.script_path}"
        assert os.access(self.script_path, os.X_OK), "Script is not executable"

    def test_usage_help(self):
        """Test that --help flag shows usage information"""
        result = subprocess.run(
            ["bash", self.script_path, "--help"],
            capture_output=True,
            text=True
        )
        assert "Usage:" in result.stdout or "Usage:" in result.stderr

    def test_create_simple_archive(self):
        """Test creating a simple tar archive without compression"""
        archive_path = os.path.join(self.test_dir, "test_simple.tar")

        self._run_script([
            f"--dir={self.test_files_dir}",
            "--mode=create",
            archive_path
        ])

        assert os.path.exists(archive_path), "Archive was not created"
        assert os.path.getsize(archive_path) > 0, "Archive is empty"
    
    def test_create_archive_with_gzip(self):
        """Test creating archive with GZIP compression"""
        archive_path = os.path.join(self.test_dir, "test_gzip.tar.gz")

        self._run_script([
            f"--dir={self.test_files_dir}",
            "--mode=create",
            "--comp=GZ",
            archive_path
        ])

        # Check for .tar.gz file
        assert os.path.exists(archive_path), f"Compressed archive not found at {archive_path}"

    def test_create_archive_with_bzip2(self):
        """Test creating archive with BZIP2 compression"""
        archive_path = os.path.join(self.test_dir, "test_bzip2.tar.bz2")

        self._run_script([
            f"--dir={self.test_files_dir}",
            "--mode=create",
            "--comp=BZ2",
            archive_path
        ])

        assert os.path.exists(archive_path), f"Compressed archive not found at {archive_path}"

    def test_create_archive_with_xz(self):
        """Test creating archive with XZ compression"""
        archive_path = os.path.join(self.test_dir, "test_xz.tar.xz")

        self._run_script([
            f"--dir={self.test_files_dir}",
            "--mode=create",
            "--comp=XZ",
            archive_path
        ])

        assert os.path.exists(archive_path), f"Compressed archive not found at {archive_path}"

    def test_extract_simple_archive(self):
        """Test extracting a simple tar archive"""
        # First create an archive
        archive_path = os.path.join(self.test_dir, "test_extract.tar")

        self._run_script([
            f"--dir={self.test_files_dir}",
            "--mode=create",
            archive_path
        ])

        # Create extraction directory
        extract_dir = os.path.join(self.test_dir, "extracted")
        os.makedirs(extract_dir)

        # Extract
        self._run_script([
            f"--dir={extract_dir}",
            "--mode=extract",
            archive_path
        ])

        # Verify extracted files
        for dir_name in ["default", "develop", "release"]:
            assert os.path.exists(os.path.join(extract_dir, dir_name)), f"{dir_name} directory not extracted"
            assert os.path.exists(os.path.join(extract_dir, f"{dir_name}.xml")), f"{dir_name}.xml not extracted"
    
    def test_extract_compressed_archive(self):
        """Test extracting a compressed archive"""
        archive_path = os.path.join(self.test_dir, "test_extract_gz.tar")

        # Create compressed archive
        self._run_script([
            f"--dir={self.test_files_dir}",
            "--mode=create",
            "--comp=GZ",
            archive_path
        ])

        # Extract
        extract_dir = os.path.join(self.test_dir, "extracted_gz")
        os.makedirs(extract_dir)

        self._run_script([
            f"--dir={extract_dir}",
            "--mode=extract",
            archive_path + ".gz"
        ])

        # Verify
        for dir_name in ["default", "develop", "release"]:
            assert os.path.exists(os.path.join(extract_dir, dir_name)), f"{dir_name} directory not extracted"
            assert os.path.exists(os.path.join(extract_dir, f"{dir_name}.xml")), f"{dir_name}.xml not extracted"

    def test_create_with_select_list(self):
        """Test creating archive with selective file list"""
        # Create select list
        select_file = os.path.join(self.test_dir, "select_list.txt")
        with open(select_file, "w") as f:
            f.write("default\n")
            f.write("default.xml\n")
        
        archive_path = os.path.join(self.test_dir, "test_select.tar")
        
        self._run_script([
            f"--dir={self.test_files_dir}",
            "--mode=create",
            f"--select={select_file}",
            archive_path
        ])
        
        # Extract and verify only selected files are present
        extract_dir = os.path.join(self.test_dir, "extracted_select")
        os.makedirs(extract_dir)
        
        self._run_script([
            f"--dir={extract_dir}",
            "--mode=extract",
            archive_path
        ])
        
        assert os.path.exists(os.path.join(extract_dir, "default")), "Selected directory not in archive"
        assert os.path.exists(os.path.join(extract_dir, "default.xml")), "Selected file not in archive"
        assert not os.path.exists(os.path.join(extract_dir, "develop")), "Non-selected directory found in archive"
    
    def test_create_with_skip_list(self):
        """Test creating archive with skip list"""
        # Create skip list
        skip_file = os.path.join(self.test_dir, "skip_list.txt")
        with open(skip_file, "w") as f:
            f.write("develop\n")
            f.write("develop.xml\n")
        
        archive_path = os.path.join(self.test_dir, "test_skip.tar")
        
        self._run_script([
            f"--dir={self.test_files_dir}",
            "--mode=create",
            f"--skip={skip_file}",
            archive_path
        ])
        
        # Extract and verify skipped files are not present
        extract_dir = os.path.join(self.test_dir, "extracted_skip")
        os.makedirs(extract_dir)
        
        self._run_script([
            f"--dir={extract_dir}",
            "--mode=extract",
            archive_path
        ])
        
        assert os.path.exists(os.path.join(extract_dir, "default")), "Non-skipped directory missing"
        assert not os.path.exists(os.path.join(extract_dir, "develop")), "Skipped directory found in archive"
        assert not os.path.exists(os.path.join(extract_dir, "develop.xml")), "Skipped file found in archive"
    
    def test_create_with_both_select_and_skip(self):
        """Test creating archive with both select and skip lists"""
        # Create select list
        select_file = os.path.join(self.test_dir, "select_both.txt")
        with open(select_file, "w") as f:
            f.write("default\n")
            f.write("develop\n")
            f.write("default.xml\n")
            f.write("develop.xml\n")
        
        # Create skip list
        skip_file = os.path.join(self.test_dir, "skip_both.txt")
        with open(skip_file, "w") as f:
            f.write("develop\n")
        
        archive_path = os.path.join(self.test_dir, "test_both.tar")
        
        self._run_script([
            f"--dir={self.test_files_dir}",
            "--mode=create",
            f"--select={select_file}",
            f"--skip={skip_file}",
            archive_path
        ])
        
        # Extract and verify
        extract_dir = os.path.join(self.test_dir, "extracted_both")
        os.makedirs(extract_dir)
        
        self._run_script([
            f"--dir={extract_dir}",
            "--mode=extract",
            archive_path
        ])
        
        # Should have default (selected, not skipped)
        assert os.path.exists(os.path.join(extract_dir, "default")), "default should be included"
        # Should not have develop (selected but skipped)
        assert not os.path.exists(os.path.join(extract_dir, "develop")), "develop should be skipped"
        # Should have files
        assert os.path.exists(os.path.join(extract_dir, "default.xml")), "default.xml should be included"
    
    def test_missing_mode_parameter(self):
        """Test that script fails without --mode parameter"""
        result = self._run_script(
            ["test.tar"],
            expect_success=False
        )
        assert result.returncode != 0, "Script should fail without mode parameter"
    
    def test_invalid_mode(self):
        """Test that script fails with invalid mode"""
        result = self._run_script(
            ["--mode=invalid", "test.tar"],
            expect_success=False
        )
        assert result.returncode != 0, "Script should fail with invalid mode"
    
    def test_invalid_compression(self):
        """Test that script fails with invalid compression type"""
        result = self._run_script(
            [f"--dir={self.test_files_dir}", "--mode=create", "--comp=INVALID", "test.tar"],
            expect_success=False
        )
        assert result.returncode != 0, "Script should fail with invalid compression"
    
    def test_nonexistent_select_file(self):
        """Test that script handles non-existent select file"""
        result = self._run_script(
            [f"--dir={self.test_files_dir}", "--mode=create", "--select=/nonexistent/file.txt", "test.tar"],
            expect_success=False
        )
        assert result.returncode != 0, "Script should fail with non-existent select file"
    
    def test_custom_working_directory(self):
        """Test using custom working directory"""
        # Create archive
        archive_path = os.path.join(self.test_dir, "test_custom_dir.tar")
        
        self._run_script([
            f"--dir={self.test_files_dir}",
            "--mode=create",
            archive_path
        ])
        
        assert os.path.exists(archive_path), "Archive not created with custom directory"
        
        # Extract and verify
        extract_dir = os.path.join(self.test_dir, "extracted_custom")
        os.makedirs(extract_dir)
        
        self._run_script([
            f"--dir={extract_dir}",
            "--mode=extract",
            archive_path
        ])
        
        assert os.path.exists(os.path.join(extract_dir, "default")), "Files not extracted to custom directory"
    
    def test_empty_select_file(self):
        """Test behavior with empty select file"""
        # Create empty select file
        select_file = os.path.join(self.test_dir, "empty_select.txt")
        open(select_file, "w").close()
        
        archive_path = os.path.join(self.test_dir, "test_empty_select.tar")
        
        # This should create an empty or minimal archive
        self._run_script([
            f"--dir={self.test_files_dir}",
            "--mode=create",
            f"--select={select_file}",
            archive_path
        ])
        
        # Archive should exist but be minimal
        assert os.path.exists(archive_path), "Archive should be created even with empty select file"
    
    def test_skip_nonexistent_files(self):
        """Test that skipping non-existent files doesn't cause errors"""
        # Create skip list with non-existent files
        skip_file = os.path.join(self.test_dir, "skip_nonexistent.txt")
        with open(skip_file, "w") as f:
            f.write("nonexistent_file.txt\n")
            f.write("nonexistent_dir\n")
        
        archive_path = os.path.join(self.test_dir, "test_skip_nonexistent.tar")
        
        # Should succeed despite non-existent files in skip list
        self._run_script([
            f"--dir={self.test_files_dir}",
            "--mode=create",
            f"--skip={skip_file}",
            archive_path
        ])
        
        assert os.path.exists(archive_path), "Archive should be created"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
